#!/bin/bash
#
# restore_kadis_db.sh — restore the Płatnik SQL Server database from S3.
#
# Backups are taken hourly by the platnik-backup CronJob
# (clusters/may-chang/sqlserver/backup-cronjob.yaml) into
#   s3://kadis-ad77fef6-backups/sqlserver/platnik_migracja/platnik_migracja_<UTC ts>.bak.gz.enc
# and expire after 14 days (bucket lifecycle rule, infra/kadis).
#
# They are encrypted client-side with AES-256-CBC. The passphrase is the
# sqlserver-backup-passphrase Secret, from Secret Manager; this script mounts it
# into the restore Job the same way it mounts the SA password, so nothing
# sensitive has to exist on the laptop. Without that passphrase the objects are
# unrecoverable — there is no escrow and no second copy.
#
#   ./restore_kadis_db.sh --list                          what exists, newest first
#   ./restore_kadis_db.sh                                 newest -> platnik_restore_<ts>
#   ./restore_kadis_db.sh --object <key>                  a specific backup
#   ./restore_kadis_db.sh --target-db platnik_migracja --replace   overwrite the live db
#
# Restoring into a NEW database is the default. Overwriting the live
# `platnik_migracja` needs --replace and a typed confirmation, because that is
# the one operation nobody should do by accident at 2am.
#
# ── MANUAL FALLBACK, if this script is broken ────────────────────────────────
# Everything below is just automation of these steps. Run them by hand if need be.
#
#   # 1. what's in the bucket (creds are in the cluster, or use your own):
#   kubectl -n sqlserver get secret sqlserver-backup-aws-creds \
#     -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d
#   aws s3 ls s3://kadis-ad77fef6-backups/sqlserver/platnik_migracja/ --region eu-central-1
#
#   # 2. get the file onto the database volume (a pod on kadis mounting
#   #    the PVC mssql-data-sqlserver-0 at /var/opt/mssql), then DECRYPT it.
#   #    Needs OpenSSL 3 — the mssql-tools image has 1.0.2g, which has no
#   #    -pbkdf2; use the mssql/server image, or your laptop:
#   openssl enc -d -aes-256-cbc -md sha512 -pbkdf2 -iter 600000 \
#     -pass env:BACKUP_PASSPHRASE -in x.bak.gz.enc -out x.bak.gz
#   #    (BACKUP_PASSPHRASE from: gcloud secrets versions access latest \
#   #     --secret=sqlserver-backup-passphrase --project=danb-ubuntu-k0s)
#   #    then gunzip it, and:
#   /opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "$SA" -Q \
#     "RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backup/x.bak'"
#   # note the two LogicalName values, then:
#   /opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "$SA" -Q \
#     "RESTORE DATABASE [platnik_restore] FROM DISK = N'/var/opt/mssql/backup/x.bak'
#      WITH MOVE '<data logical>' TO '/var/opt/mssql/data/platnik_restore.mdf',
#           MOVE '<log logical>'  TO '/var/opt/mssql/data/platnik_restore_log.ldf',
#           RECOVERY, STATS = 10"
#
#   # 3. delete the .bak afterwards — it sits on the live database's volume.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

NAMESPACE="sqlserver"
BUCKET="kadis-ad77fef6-backups"
PREFIX="sqlserver/platnik_migracja"
REGION="eu-central-1"
PVC="mssql-data-sqlserver-0"
NODE="kadis"

AWSCLI_IMAGE="amazon/aws-cli:2.36.30@sha256:da37c08f8e00a64c09acd46e8ce5c3dd30b291046029def45566aa9ccd7b398b"
MSSQL_IMAGE="mcr.microsoft.com/mssql-tools@sha256:62556500522072535cb3df2bb5965333dded9be47000473e9e0f84118e248642"
# Decryption needs OpenSSL 3 for -pbkdf2. mssql-tools ships 1.0.2g (2016) and
# aws-cli ships no openssl at all, so the decrypt step borrows the SQL Server
# image — same digest as statefulset.yaml, already on the node. Mirrors the
# `encrypt` initContainer in backup-cronjob.yaml; the two must stay in step.
SERVER_IMAGE="mcr.microsoft.com/mssql/server:2022-latest@sha256:ba4c8329f48fb8f02e1416be6a930ebfd71268caee78aa985f3af4315e457c89"

OBJECT=""
TARGET_DB=""
REPLACE="false"
LIST_ONLY="false"

# Print the header down to the MANUAL FALLBACK divider, rather than a hardcoded
# line range — the range silently went stale the moment the header grew.
usage() { sed -n '3,/^# ── MANUAL FALLBACK/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)      LIST_ONLY="true"; shift ;;
    --object)    OBJECT="${2:?--object needs a key}"; shift 2 ;;
    --target-db) TARGET_DB="${2:?--target-db needs a name}"; shift 2 ;;
    --replace)   REPLACE="true"; shift ;;
    -h|--help)   usage 0 ;;
    *)           echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

# Run an aws-cli command in-cluster, so the bucket credentials never have to
# exist on whatever laptop is doing the restore.
aws_in_cluster() {
  kubectl -n "$NAMESPACE" run "aws-$RANDOM" \
    --rm --attach --quiet --restart=Never --image="$AWSCLI_IMAGE" \
    --env="AWS_REGION=$REGION" \
    --overrides='{"spec":{"containers":[{"name":"aws","image":"'"$AWSCLI_IMAGE"'",
      "command":["aws"],"args":'"$1"',
      "env":[{"name":"AWS_REGION","value":"'"$REGION"'"},
             {"name":"AWS_ACCESS_KEY_ID","valueFrom":{"secretKeyRef":{"name":"sqlserver-backup-aws-creds","key":"AWS_ACCESS_KEY_ID"}}},
             {"name":"AWS_SECRET_ACCESS_KEY","valueFrom":{"secretKeyRef":{"name":"sqlserver-backup-aws-creds","key":"AWS_SECRET_ACCESS_KEY"}}}]}]}}' \
    --command -- aws 2>/dev/null
}

echo "== backups in s3://$BUCKET/$PREFIX/ =="
LISTING="$(aws_in_cluster '["s3","ls","s3://'"$BUCKET"'/'"$PREFIX"'/"]' | sort -r || true)"
if [[ -z "$LISTING" ]]; then
  echo "none found — has the CronJob run yet? (kubectl -n $NAMESPACE get cronjob platnik-backup)" >&2
  exit 1
fi
echo "$LISTING"
[[ "$LIST_ONLY" == "true" ]] && exit 0

if [[ -z "$OBJECT" ]]; then
  OBJECT="$PREFIX/$(echo "$LISTING" | head -1 | awk '{print $4}')"
fi
TS="$(date -u +%Y%m%dT%H%M%SZ)"
[[ -n "$TARGET_DB" ]] || TARGET_DB="platnik_restore_$TS"

# Everything the CronJob writes is encrypted, but --object can still name a key
# from before that change. Branch on the suffix rather than assuming, so a
# legacy .bak.gz restores by skipping the decrypt step instead of failing in it.
case "$OBJECT" in
  *.enc) LOCAL_SUFFIX="bak.gz.enc" ;;
  *)     LOCAL_SUFFIX="bak.gz" ;;
esac

echo
echo "  source : s3://$BUCKET/$OBJECT"
echo "  target : [$TARGET_DB]"
if [[ "$REPLACE" == "true" ]]; then
  echo "  mode   : REPLACE — the existing [$TARGET_DB] will be OVERWRITTEN"
else
  echo "  mode   : create new database (live data untouched)"
fi
echo

if [[ "$REPLACE" == "true" ]]; then
  echo "This destroys the current contents of [$TARGET_DB] and cannot be undone."
  read -p "Type the database name to confirm: " typed
  if [[ "$typed" != "$TARGET_DB" ]]; then echo "Aborted."; exit 1; fi
fi
read -p "Proceed? [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo "Aborted."; exit 1; fi

JOB="platnik-restore-$(date -u +%H%M%S)"
REPLACE_CLAUSE=""
[[ "$REPLACE" == "true" ]] && REPLACE_CLAUSE=", REPLACE"

cleanup() { kubectl -n "$NAMESPACE" delete job "$JOB" --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup EXIT

kubectl -n "$NAMESPACE" apply -f - >/dev/null <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB
  namespace: $NAMESPACE
  labels: { app: sqlserver, component: restore }
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: $NODE
      # root on purpose: msodbcsql 13 resolves its UID against /etc/passwd and
      # fails with SQLAllocHandle if it can't, and 10001 is absent from the
      # tools image. fsGroup keeps created files group-owned by mssql.
      securityContext: { fsGroup: 10001 }
      volumes:
        - name: mssql-data
          persistentVolumeClaim: { claimName: $PVC }
      initContainers:
        - name: fetch
          image: $AWSCLI_IMAGE
          env:
            - name: AWS_REGION
              value: "$REGION"
            - name: AWS_ACCESS_KEY_ID
              valueFrom: { secretKeyRef: { name: sqlserver-backup-aws-creds, key: AWS_ACCESS_KEY_ID } }
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom: { secretKeyRef: { name: sqlserver-backup-aws-creds, key: AWS_SECRET_ACCESS_KEY } }
          volumeMounts:
            - { name: mssql-data, mountPath: /var/opt/mssql }
          command: ["/bin/bash", "-c"]
          args:
            - |
              set -euo pipefail
              # Group-writable and setgid: the server process (uid 10001) has
              # to be able to write its own .bak files here later, and this
              # container is root with a 022 umask. See backup-cronjob.yaml.
              mkdir -p /var/opt/mssql/backup
              chmod 2775 /var/opt/mssql/backup
              echo "downloading s3://$BUCKET/$OBJECT"
              aws s3 cp "s3://$BUCKET/$OBJECT" /var/opt/mssql/backup/restore_$TS.$LOCAL_SUFFIX --only-show-errors
              ls -la /var/opt/mssql/backup/restore_$TS.$LOCAL_SUFFIX
        - name: decrypt
          image: $SERVER_IMAGE
          env:
            - name: BACKUP_PASSPHRASE
              valueFrom: { secretKeyRef: { name: sqlserver-backup-passphrase, key: passphrase } }
          volumeMounts:
            - { name: mssql-data, mountPath: /var/opt/mssql }
          command: ["/bin/bash", "-c"]
          args:
            - |
              set -euo pipefail
              ENC=/var/opt/mssql/backup/restore_$TS.bak.gz.enc
              # A legacy plaintext object never produced this file — say so and
              # let the restore proceed rather than failing on its absence.
              if [ ! -f "\$ENC" ]; then echo "object is not encrypted — nothing to decrypt"; exit 0; fi
              if [ -z "\${BACKUP_PASSPHRASE:-}" ]; then
                echo "BACKUP_PASSPHRASE is empty — has sqlserver-backup-passphrase synced?" >&2
                exit 1
              fi
              echo "decrypting \$(basename "\$ENC")"
              # Must match backup-cronjob.yaml's encrypt step exactly. A wrong
              # passphrase surfaces here as "bad decrypt", which reads like a
              # corrupt download and is not one.
              openssl enc -d -aes-256-cbc -md sha512 -pbkdf2 -iter 600000 \
                -pass env:BACKUP_PASSPHRASE -in "\$ENC" -out /var/opt/mssql/backup/restore_$TS.bak.gz
              rm -f "\$ENC"
              ls -la /var/opt/mssql/backup/restore_$TS.bak.gz
      containers:
        - name: restore
          image: $MSSQL_IMAGE
          env:
            - name: SA_PASSWORD
              valueFrom: { secretKeyRef: { name: sqlserver-sa-password, key: password } }
          volumeMounts:
            - { name: mssql-data, mountPath: /var/opt/mssql }
          command: ["/bin/bash", "-c"]
          args:
            - |
              set -euo pipefail
              SQLCMD=/opt/mssql-tools/bin/sqlcmd
              BAK=/var/opt/mssql/backup/restore_$TS.bak

              # The .bak sits on the live database's volume, so it goes away
              # whatever happens next.
              trap 'rm -f "\$BAK" "\$BAK.gz" "\$BAK.gz.enc"' EXIT

              gunzip -f "\$BAK.gz"
              sa() { "\$SQLCMD" -S sqlserver -U sa -P "\$SA_PASSWORD" -b -x -h -1 -W "\$@"; }

              # Read the real logical names out of the backup rather than
              # assuming them — they differ between databases.
              echo "== files in the backup =="
              sa -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'\$BAK'" -s "|"

              # Capture the logical names by piping FILELISTONLY into a temp
              # table — the names differ per database and guessing them is how
              # restores fail at the worst moment.
              read -r DATA_LOGICAL LOG_LOGICAL <<< "\$(
                sa -Q "SET NOCOUNT ON;
                       CREATE TABLE #fl (LogicalName nvarchar(128), PhysicalName nvarchar(260), Type char(1),
                         FileGroupName nvarchar(128), Size numeric(20,0), MaxSize numeric(20,0), FileID bigint,
                         CreateLSN numeric(25,0), DropLSN numeric(25,0), UniqueID uniqueidentifier, ReadOnlyLSN numeric(25,0),
                         ReadWriteLSN numeric(25,0), BackupSizeInBytes bigint, SourceBlockSize int, FileGroupID int,
                         LogGroupGUID uniqueidentifier, DifferentialBaseLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier,
                         IsReadOnly bit, IsPresent bit, TDEThumbprint varbinary(32), SnapshotUrl nvarchar(360));
                       INSERT INTO #fl EXEC('RESTORE FILELISTONLY FROM DISK = N''\$BAK''');
                       SELECT (SELECT TOP 1 LogicalName FROM #fl WHERE Type = 'D') + ' ' +
                              (SELECT TOP 1 LogicalName FROM #fl WHERE Type = 'L');" | tr -d '\r'
              )"
              echo "data file: \$DATA_LOGICAL   log file: \$LOG_LOGICAL"

              echo "== restoring into [$TARGET_DB] =="
              sa -Q "RESTORE DATABASE [$TARGET_DB] FROM DISK = N'\$BAK'
                     WITH MOVE N'\$DATA_LOGICAL' TO N'/var/opt/mssql/data/$TARGET_DB.mdf',
                          MOVE N'\$LOG_LOGICAL'  TO N'/var/opt/mssql/data/${TARGET_DB}_log.ldf',
                          RECOVERY, STATS = 10$REPLACE_CLAUSE"

              echo "== proof =="
              sa -Q "SET NOCOUNT ON;
                     SELECT 'tables: ' + CAST(COUNT(*) AS varchar(10)) FROM [$TARGET_DB].sys.tables;
                     SELECT 'WersjaBazy: ' + WARTOSC1 FROM [$TARGET_DB].dbo.PARAM_KONF WHERE NAZWA = 'WersjaBazy';"
YAML

echo "restoring (job/$JOB) ..."
kubectl -n "$NAMESPACE" wait --for=condition=ready pod -l job-name="$JOB" --timeout=300s >/dev/null 2>&1 || true
kubectl -n "$NAMESPACE" logs -f "job/$JOB" 2>/dev/null || true

if kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$JOB" --timeout=1800s >/dev/null 2>&1; then
  echo
  echo "Restored into [$TARGET_DB]."
  [[ "$REPLACE" == "true" ]] || echo "Drop it when you're done:  DROP DATABASE [$TARGET_DB]"
else
  echo
  echo "Restore FAILED — logs above. The job is left in place for triage:" >&2
  echo "  kubectl -n $NAMESPACE logs job/$JOB --all-containers" >&2
  trap - EXIT
  exit 1
fi
