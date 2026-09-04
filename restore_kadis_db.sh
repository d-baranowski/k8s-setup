#!/bin/bash
#
# restore_kadis_db.sh — restore the Płatnik SQL Server database from S3.
#
# Backups are taken hourly by the platnik-backup CronJob
# (clusters/may-chang/sqlserver/backup-cronjob.yaml) into
#   s3://kadis-ad77fef6-backups/sqlserver/platnik/platnik_<UTC timestamp>.bak.gz
# and expire after 14 days (bucket lifecycle rule, infra/kadis).
#
#   ./restore_kadis_db.sh --list                          what exists, newest first
#   ./restore_kadis_db.sh                                 newest -> platnik_restore_<ts>
#   ./restore_kadis_db.sh --object <key>                  a specific backup
#   ./restore_kadis_db.sh --target-db platnik --replace   overwrite the live database
#
# Restoring into a NEW database is the default. Overwriting the live `platnik`
# needs --replace and a typed confirmation, because that is the one operation
# nobody should do by accident at 2am.
#
# ── MANUAL FALLBACK, if this script is broken ────────────────────────────────
# Everything below is just automation of these steps. Run them by hand if need be.
#
#   # 1. what's in the bucket (creds are in the cluster, or use your own):
#   kubectl -n sqlserver get secret sqlserver-backup-aws-creds \
#     -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d
#   aws s3 ls s3://kadis-ad77fef6-backups/sqlserver/platnik/ --region eu-central-1
#
#   # 2. get the file onto the database volume (a pod on kadis mounting
#   #    the PVC mssql-data-sqlserver-0 at /var/opt/mssql), gunzip it, then:
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
PREFIX="sqlserver/platnik"
REGION="eu-central-1"
PVC="mssql-data-sqlserver-0"
NODE="kadis"

AWSCLI_IMAGE="amazon/aws-cli:2.36.30@sha256:da37c08f8e00a64c09acd46e8ce5c3dd30b291046029def45566aa9ccd7b398b"
MSSQL_IMAGE="mcr.microsoft.com/mssql-tools@sha256:62556500522072535cb3df2bb5965333dded9be47000473e9e0f84118e248642"

OBJECT=""
TARGET_DB=""
REPLACE="false"
LIST_ONLY="false"

usage() { sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

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
              mkdir -p /var/opt/mssql/backup
              echo "downloading s3://$BUCKET/$OBJECT"
              aws s3 cp "s3://$BUCKET/$OBJECT" /var/opt/mssql/backup/restore_$TS.bak.gz --only-show-errors
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
              trap 'rm -f "\$BAK" "\$BAK.gz"' EXIT

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
