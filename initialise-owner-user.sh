#!/bin/bash
set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

NAMESPACE="default"
CLUSTER_NAME="db-cluster"
OWNER_PASSWORD_SECRET="psql-owner-password"
DB_NAME="postgres"

log_info "=========================================="
log_info "Initialising owner user on CNPG cluster"
log_info "=========================================="

log_info "Validating kubectl connection..."
kubectl cluster-info >/dev/null 2>&1 || { log_error "kubectl failed"; exit 1; }

log_info "Validating namespace ${NAMESPACE}..."
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || { log_error "Namespace not found"; exit 1; }

log_info "Validating CNPG cluster ${CLUSTER_NAME}..."
kubectl get cluster.postgresql.cnpg.io "${CLUSTER_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1 || { log_error "Cluster not found"; exit 1; }

log_info "Validating secret ${OWNER_PASSWORD_SECRET}..."
kubectl get secret "${OWNER_PASSWORD_SECRET}" -n "${NAMESPACE}" >/dev/null 2>&1 || { log_error "Secret not found"; exit 1; }

log_info "Extracting owner password from secret..."
OWNER_PASSWORD=$(kubectl get secret "${OWNER_PASSWORD_SECRET}" -n "${NAMESPACE}" -o jsonpath='{.data.password}' | base64 -d)
[ -z "$OWNER_PASSWORD" ] && { log_error "Password is empty"; exit 1; }
log_info "Password extracted (length: ${#OWNER_PASSWORD})"

log_info "=========================================="
log_info "Pre-flight checks passed"
log_info "=========================================="

log_info "Retrieving db-cluster pods..."
pods=$(kubectl get pods -n "${NAMESPACE}" -l "cnpg.io/cluster=${CLUSTER_NAME}" -o jsonpath='{.items[*].metadata.name}')
[ -z "$pods" ] && { log_error "No pods found"; exit 1; }
log_info "Found pods: ${pods}"

failed_pods=()
success_pods=()

for pod in $pods; do
    log_info "=========================================="
    log_info "Processing pod: ${pod}"
    log_info "=========================================="

    needs_setup=false

    # Check owner exists (using local socket - always works)
    log_info "Checking if owner role exists..."
    if ! kubectl exec -n "${NAMESPACE}" "${pod}" -- bash -c "psql -U postgres -d ${DB_NAME} -tAc \"select 1 from pg_roles where rolname='owner';\" 2>/dev/null | grep -q 1"; then
        log_warn "Owner role does not exist"
        needs_setup=true
    else
        log_info "Owner role exists"
    fi

    # Check owner can login (try both local and network)
    log_info "Testing owner login via network..."
    login_test=$(kubectl exec -n "${NAMESPACE}" "${pod}" -- bash -c "OWNER_PASSWORD='${OWNER_PASSWORD}' && export PGPASSWORD=\$OWNER_PASSWORD && psql -h db-cluster-rw.${NAMESPACE}.svc.cluster.local -p 5432 -U owner -d ${DB_NAME} -tAc 'select 1;' 2>&1")
    if [ $? -eq 0 ] && echo "$login_test" | grep -q "^1$"; then
        log_info "Owner login works"
    else
        log_warn "Owner login failed"
        log_warn "Error: $login_test"
        needs_setup=true
    fi

    # Check owner has login permission
    log_info "Checking owner LOGIN permission..."
    has_login=$(kubectl exec -n "${NAMESPACE}" "${pod}" -- bash -c "psql -U postgres -d ${DB_NAME} -tAc \"select rolcanlogin from pg_roles where rolname='owner';\" 2>/dev/null" | tr -d ' ')
    if [ "$has_login" = "t" ]; then
        log_info "Owner has LOGIN permission"
    else
        log_warn "Owner missing LOGIN permission"
        needs_setup=true
    fi

    # Setup if needed
    if [ "$needs_setup" = true ]; then
        log_warn "Setting up owner user..."
        # Use local socket for setup (always works)
        setup_result=$(kubectl exec -n "${NAMESPACE}" "${pod}" -- bash -c "OWNER_PASSWORD='${OWNER_PASSWORD}' && psql -v ON_ERROR_STOP=1 -U postgres -d ${DB_NAME} <<'EOSQL'
ALTER ROLE owner WITH LOGIN PASSWORD '${OWNER_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE postgres TO owner;
EOSQL
" 2>&1)
        setup_rc=$?

        if [ $setup_rc -ne 0 ]; then
            log_error "Failed to setup owner (exit: $setup_rc)"
            log_error "Output: $setup_result"
            failed_pods+=("$pod")
            continue
        fi
        log_info "Owner setup complete"
    else
        log_info "Owner already configured"
    fi

    # Verify login
    log_info "Verifying owner login..."
    verify=$(kubectl exec -n "${NAMESPACE}" "${pod}" -- bash -c "OWNER_PASSWORD='${OWNER_PASSWORD}' && export PGPASSWORD=\$OWNER_PASSWORD && psql -h db-cluster-rw.${NAMESPACE}.svc.cluster.local -p 5432 -U owner -d ${DB_NAME} -tAc 'select current_user;' 2>&1")
    verify_rc=$?

    if [ $verify_rc -eq 0 ] && echo "$verify" | grep -q "owner"; then
        log_info "✓ Verified: $verify"
        success_pods+=("$pod")
    else
        log_error "✗ Verification failed (exit: $verify_rc)"
        log_error "Output: $verify"
        failed_pods+=("$pod")
    fi
done

log_info "=========================================="
log_info "Summary"
log_info "=========================================="
if [ ${#success_pods[@]} -gt 0 ]; then
    log_info "Success: ${#success_pods[@]}"
    for p in "${success_pods[@]}"; do log_info "  ✓ $p"; done
else
    log_warn "Success: 0"
fi

if [ ${#failed_pods[@]} -gt 0 ]; then
    log_error "Failed: ${#failed_pods[@]}"
    for p in "${failed_pods[@]}"; do log_error "  ✗ $p"; done
    exit 1
fi

log_info "=========================================="
log_info "Done - owner user initialized"
log_info "=========================================="
exit 0
