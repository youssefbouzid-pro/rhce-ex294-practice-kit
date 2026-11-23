#!/usr/bin/env bash
# RHCE EX294 practice grader — 300 points, 210 pass mark.
# Run as the Ansible control-node user (student) from workstation.lab.example.com.
# Requires: ansible-core, python3, ssh access to managed nodes, sudo/become access.
set -uo pipefail

BASE="${HOME}/ansible"
INV="${BASE}/inventory"
CFG="${BASE}/ansible.cfg"
MAX=300
PASS=210
TOTAL=0
REPORT_DIR="${HOME}/grading-reports"
mkdir -p "$REPORT_DIR"
REPORT="${REPORT_DIR}/rhce-grade-$(date +%Y%m%d-%H%M%S).txt"
TMP="$(mktemp -d)"
chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT
# Exam statement: root/become password is redhat. This temp file is private and removed on exit.
printf '%s\n' redhat > "$TMP/become-pass"
chmod 600 "$TMP/become-pass"
export ANSIBLE_CONFIG="$CFG"
REMOTE_USER="${ANSIBLE_REMOTE_USER:-devops}"

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$NC" "$*"; }
fail(){ printf '%s[FAIL]%s %s\n' "$RED" "$NC" "$*"; }
warn(){ printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$*"; }
log(){ printf '%s\n' "$*" | tee -a "$REPORT"; }

# Run one remote shell assertion through Ansible. Returns success only if every
# host in the requested inventory group succeeds.
remote(){
  local group="$1" command="$2"
  [[ -f "$INV" ]] || return 1
  ansible "$group" -i "$INV" -u "$REMOTE_USER" -m ansible.builtin.shell \
    -a "$command" -b --become-password-file "$TMP/become-pass" \
    --forks 20 >/dev/null 2>&1
}
local_file(){ [[ -f "$1" ]]; }
contains(){ grep -Eiq -- "$2" "$1" 2>/dev/null; }
check(){
  local label="$1" points="$2"; shift 2
  if "$@"; then
    ok "$label (+$points)"
    TOTAL=$((TOTAL+points)); log "[OK] $label (+$points)"
  else
    fail "$label (0/$points)"
    log "[FAIL] $label (0/$points)"
  fi
}
task(){ log ""; log "============================================================"; log "$1"; log "============================================================"; }

clear 2>/dev/null || true
echo "============================================================"
echo "             RHCE EX294 PRACTICE GRADER"
echo "============================================================"
read -rp "Student name: " STUDENT
STUDENT="${STUDENT:-Unknown}"
echo "Student: $STUDENT | User: $(id -un) | Host: $(hostname -f 2>/dev/null || hostname)"
echo "The grader will query managed nodes using Ansible. It does not change lab configuration."
log "RHCE EX294 | Student: $STUDENT | Date: $(date) | User: $(id -un)"
log "Inventory: $INV | Remote user: $REMOTE_USER | Maximum: $MAX | Pass: $PASS"

# T1 — 20
task "TASK 1 — INSTALL AND CONFIGURE ANSIBLE (20)"
check "Project directory exists" 2 test -d "$BASE"
check "Inventory exists" 2 test -f "$INV"
check "ansible.cfg exists" 2 test -f "$CFG"
check "ansible-core executable installed" 2 bash -c 'command -v ansible >/dev/null'
check "Inventory contains all required hosts and groups" 4 bash -c 'grep -q "servera.lab.example.com" "$1" && grep -q "serverb.lab.example.com" "$1" && grep -q "serverc.lab.example.com" "$1" && grep -q "serverd.lab.example.com" "$1" && grep -Eq "^[[:space:]]*\\[dev\\]" "$1" && grep -Eq "^[[:space:]]*\\[test\\]" "$1" && grep -Eq "^[[:space:]]*\\[prod\\]" "$1" && grep -Eq "^[[:space:]]*\\[balancers\\]" "$1"' _ "$INV"
check "Inventory includes stated node addresses" 2 bash -c 'grep -q "10.0.20.2" "$1" && grep -q "10.0.20.3" "$1" && grep -q "10.0.20.4" "$1" && grep -q "10.0.20.5" "$1"' _ "$INV"
check "ansible.cfg points to required inventory, roles and collections" 4 bash -c 'grep -Eq "inventory[[:space:]]*=[[:space:]]*/home/student/ansible/inventory" "$1" && grep -Eq "roles_path[[:space:]]*=.* /home/student/ansible/roles|roles_path[[:space:]]*=[[:space:]]*/home/student/ansible/roles" "$1" && grep -Eq "collections_paths[[:space:]]*=.* /home/student/ansible/collections|collections_paths[[:space:]]*=[[:space:]]*/home/student/ansible/collections" "$1"' _ "$CFG"
check "Inventory parses successfully" 2 ansible-inventory -i "$INV" --list

# T2 — 20
task "TASK 2 — DNF REPOSITORIES (20)"
check "adhoc.yml exists" 2 test -f "$BASE/adhoc.yml"
check "baseos repo exists and is enabled on all nodes" 5 remote all "grep -RqsE '^\[baseos\]' /etc/yum.repos.d && grep -RqsE '^[[:space:]]*enabled=1' /etc/yum.repos.d/* && grep -RqsE 'baseos|BaseOS' /etc/yum.repos.d/*"
check "baseos URL, GPG check and key configured" 3 remote all "grep -Rqs 'http://content/rhel9.0/x86_64/dvd/BaseOS' /etc/yum.repos.d && grep -Rqs 'gpgcheck=1' /etc/yum.repos.d && grep -Rqs 'RPM-GPG-KEY-redhat-release' /etc/yum.repos.d"
check "appstream repo exists and is enabled on all nodes" 5 remote all "grep -RqsE '^\[appstream\]' /etc/yum.repos.d && grep -Rqs 'http://content/rhel9.0/x86_64/dvd/AppStream' /etc/yum.repos.d"
check "appstream GPG validation configured" 3 remote all "grep -Rqs 'gpgcheck=1' /etc/yum.repos.d && grep -Rqs 'RPM-GPG-KEY-redhat-release' /etc/yum.repos.d"
check "adhoc.yml syntax check" 2 ansible-playbook -i "$INV" "$BASE/adhoc.yml" --syntax-check

# T3 — 10
task "TASK 3 — COLLECTIONS (10)"
check "collections directory exists" 2 test -d "$BASE/collections"
check "ansible.posix collection installed" 3 test -d "$BASE/collections/ansible_collections/ansible/posix"
check "redhat.rhel_system_roles collection installed" 3 test -d "$BASE/collections/ansible_collections/redhat/rhel_system_roles"
check "Both collections appear in collection listing" 2 bash -c 'ansible-galaxy collection list -p "$1" 2>/dev/null | grep -q "ansible.posix" && ansible-galaxy collection list -p "$1" 2>/dev/null | grep -q "redhat.rhel_system_roles"' _ "$BASE/collections"

# T4 — 10
task "TASK 4 — GALAXY ROLES (10)"
check "roles directory exists" 2 test -d "$BASE/roles"
check "balancer role installed" 3 test -d "$BASE/roles/balancer"
check "phpinfo role installed" 3 test -d "$BASE/roles/phpinfo"
check "Galaxy requirements file exists under roles" 2 bash -c 'find "$1" -maxdepth 2 -type f \( -iname "requirements.yml" -o -iname "requirements.yaml" \) | grep -q .' _ "$BASE/roles"

# T5 — 15
task "TASK 5 — OFFLINE APACHE ROLE (15)"
check "apache role main task file exists" 2 test -f "$BASE/roles/apache/tasks/main.yml"
check "apache template exists" 2 test -f "$BASE/roles/apache/templates/template.j2"
check "apache role installs httpd and enables/starts service" 3 bash -c 'grep -Rqs "httpd" "$1/tasks" && grep -RqsE "enabled:[[:space:]]*true" "$1/tasks" && grep -RqsE "state:[[:space:]]*started" "$1/tasks"' _ "$BASE/roles/apache"
check "Template contains FQDN and IP variables" 2 bash -c 'grep -RqsE "ansible_fqdn|inventory_hostname" "$1" && grep -RqsE "ansible_default_ipv4|ansible_host" "$1"' _ "$BASE/roles/apache/templates/template.j2"
check "apache_role.yml syntax check" 2 ansible-playbook -i "$INV" "$BASE/apache_role.yml" --syntax-check
check "httpd active and enabled on dev nodes" 2 remote dev "systemctl is-active httpd >/dev/null && systemctl is-enabled httpd >/dev/null"
check "Rendered page contains servera FQDN and address" 2 remote dev "test -f /var/www/html/index.html && grep -q 'servera.lab.example.com' /var/www/html/index.html"

# T6 — 40
task "TASK 6 — BALANCER AND PHPINFO ROLES (40)"
check "roles.yml exists and passes syntax check" 4 bash -c 'test -f "$1/roles.yml" && ansible-playbook -i "$1/inventory" "$1/roles.yml" --syntax-check >/dev/null' _ "$BASE"
check "balancer role is applied to balancers group" 4 bash -c 'grep -q "balancer" "$1/roles.yml" && grep -qE "balancers" "$1/roles.yml"' _ "$BASE"
check "serverd HTTP endpoint is reachable" 4 remote balancers "curl -fsS --max-time 8 http://serverd.lab.example.com/ >/dev/null"
check "Load balancer returns servera and serverc responses over repeated requests" 8 remote balancers "out=\$(for i in \$(seq 1 12); do curl -fsS --max-time 4 http://serverd.lab.example.com/ 2>/dev/null; echo; done); echo \"\$out\" | grep -q 'Welcome to servera.lab.example.com' && echo \"\$out\" | grep -q 'Welcome to serverc.lab.example.com'"
check "phpinfo role is applied to webservers group" 4 bash -c 'grep -q "phpinfo" "$1/roles.yml" && grep -qE "webservers" "$1/roles.yml"' _ "$BASE"
check "serverc serves expected welcome response" 5 remote prod "curl -fsS --max-time 8 http://serverc.lab.example.com/ | grep -q 'Welcome to serverc.lab.example.com'"
check "serverc page exposes PHP information" 5 remote prod "curl -fsS --max-time 8 http://serverc.lab.example.com/ | grep -Eqi 'PHP Version|phpinfo\\(\\)|PHP Variables|PHP License'"
check "Role playbook includes version 1.0 response content" 6 bash -c 'grep -Rqs "version 1.0" "$1/roles/balancer" "$1/roles/phpinfo"' _ "$BASE"

# T7 — 25
task "TASK 7 — TIMESYNC AND SELINUX SYSTEM ROLES (25)"
check "timesync.yml exists and syntax checks" 3 bash -c 'test -f "$1/timesync.yml" && ansible-playbook -i "$1/inventory" "$1/timesync.yml" --syntax-check >/dev/null' _ "$BASE"
check "Timesync config contains NTP server and iburst" 4 bash -c 'grep -q "172.25.254.254" "$1/timesync.yml" && grep -q "iburst" "$1/timesync.yml" && grep -q "timesync" "$1/timesync.yml"' _ "$BASE"
check "chronyd active and enabled on all nodes" 6 remote all "systemctl is-active chronyd >/dev/null && systemctl is-enabled chronyd >/dev/null"
check "chrony config uses requested NTP server with iburst" 4 remote all "grep -RqsE 'server[[:space:]]+172.25.254.254[[:space:]]+.*iburst|pool[[:space:]]+172.25.254.254[[:space:]]+.*iburst' /etc/chrony.conf /etc/chrony.d 2>/dev/null"
check "selinux.yml exists, uses role and syntax checks" 4 bash -c 'test -f "$1/selinux.yml" && grep -qi selinux "$1/selinux.yml" && ansible-playbook -i "$1/inventory" "$1/selinux.yml" --syntax-check >/dev/null' _ "$BASE"
check "SELinux enforcing on all nodes" 4 remote all "test \"\$(getenforce)\" = Enforcing && grep -Eq '^SELINUX=enforcing' /etc/selinux/config"

# T8 — 15
task "TASK 8 — PACKAGE MANAGEMENT (15)"
check "packages.yml has separate plays and syntax checks" 3 bash -c 'test -f "$1/packages.yml" && ansible-playbook -i "$1/inventory" "$1/packages.yml" --syntax-check >/dev/null && test \"$(grep -cE \"^-?[[:space:]]*hosts:\" \"$1/packages.yml\")\" -ge 3' _ "$BASE"
check "vsftpd and mariadb-server installed on dev and test" 5 remote 'dev:test' "rpm -q vsftpd mariadb-server >/dev/null"
check "RPM Development Tools group installed on prod" 4 remote prod "dnf group list --installed 2>/dev/null | grep -qi 'Development Tools'"
check "Update task targets dev group" 3 bash -c 'grep -qE "hosts:[[:space:]]*dev" "$1/packages.yml" && grep -Eqi "state:[[:space:]]*latest|name:[[:space:]]*['\"'\"']\\*['\"'\"']" "$1/packages.yml"' _ "$BASE"

# T9 — 15
task "TASK 9 — WEBCONTENT AND SELINUX CONTEXT (15)"
check "/devweb exists with group devops and mode 2775 on dev" 4 remote dev "test -d /devweb && test \"\$(stat -c %G /devweb)\" = devops && test \"\$(stat -c %a /devweb)\" = 2775"
check "index.html contains requested content" 3 remote dev "test -f /devweb/index.html && grep -q 'Developement' /devweb/index.html"
check "HTTPD SELinux context applied" 3 remote dev "ls -Zd /devweb | grep -Eq 'httpd_sys_content_t|httpd_sys_rw_content_t'"
check "webroot symlink points to /devweb" 3 remote dev "test -L /var/www/html/devweb && test \"\$(readlink -f /var/www/html/devweb)\" = /devweb"
check "webcontent.yml exists and syntax checks" 2 bash -c 'test -f "$1/webcontent.yml" && ansible-playbook -i "$1/inventory" "$1/webcontent.yml" --syntax-check >/dev/null' _ "$BASE"

# T10 — 25
task "TASK 10 — HARDWARE REPORT (25)"
check "hwreport.yml exists and syntax checks" 3 bash -c 'test -f "$1/hwreport.yml" && ansible-playbook -i "$1/inventory" "$1/hwreport.yml" --syntax-check >/dev/null' _ "$BASE"
check "Playbook downloads the supplied hardware template URL" 2 bash -c 'grep -q "content.example.com/Rhce/hwreport.txt" "$1/hwreport.yml"' _ "$BASE"
check "Report file exists on every managed node" 5 remote all "test -f /root/hwreport.txt"
check "Report contains all six required keys" 6 remote all "f=/root/hwreport.txt; for k in HOSTNAME MEMORY BIOS CPU DISK_SIZE_VDA DISK_SIZE_VDB; do grep -qE \"^\${k}=.+\" \"\$f\" || exit 1; done"
check "Missing data represented as NONE (not blank)" 4 remote all "awk -F= '/^(HOSTNAME|MEMORY|BIOS|CPU|DISK_SIZE_VDA|DISK_SIZE_VDB)=/{if (NF<2 || \$2==\"\") bad=1} END{exit bad}' /root/hwreport.txt"
check "HOSTNAME field is populated with FQDN" 5 remote all "grep -qE '^HOSTNAME=[A-Za-z0-9.-]+\\.[A-Za-z]+' /root/hwreport.txt"

# T11 — 10
task "TASK 11 — /etc/issue (10)"
check "/etc/issue is Development on dev" 3 remote dev "grep -qx 'Development' /etc/issue"
check "/etc/issue is Test on test" 2 remote test "grep -qx 'Test' /etc/issue"
check "/etc/issue is Production on prod" 3 remote prod "grep -qx 'Production' /etc/issue"
check "issue.yml exists and syntax checks" 2 bash -c 'test -f "$1/issue.yml" && ansible-playbook -i "$1/inventory" "$1/issue.yml" --syntax-check >/dev/null' _ "$BASE"

# T12 — 15
task "TASK 12 — /etc/myhosts (15)"
check "hosts.yml and myhosts.j2 exist" 3 bash -c 'test -f "$1/hosts.yml" && find "$1" -maxdepth 4 -name myhosts.j2 | grep -q .' _ "$BASE"
check "hosts.yml syntax checks and targets dev" 3 bash -c 'ansible-playbook -i "$1/inventory" "$1/hosts.yml" --syntax-check >/dev/null && grep -qE "hosts:[[:space:]]*dev" "$1/hosts.yml"' _ "$BASE"
check "/etc/myhosts contains supplied localhost lines" 2 remote dev "grep -qx '127.0.0.1 localhost.localdomain localhost' /etc/myhosts && grep -qx '192.168.0.1 localhost.localdomain localhost' /etc/myhosts"
check "/etc/myhosts contains all four expected host mappings" 5 remote dev "f=/etc/myhosts; grep -q '172.25.250.10 servera.lab.example.com servera' \$f && grep -q '172.25.250.11 serverb.lab.example.com serverb' \$f && grep -q '172.25.250.12 serverc.lab.example.com serverc' \$f && grep -q '172.25.250.13 serverd.lab.example.com serverd' \$f"
check "Template includes hostvars and FQDN/hostname fields" 2 bash -c 'f=$(find "$1" -maxdepth 4 -name myhosts.j2 | head -1); grep -q "hostvars" "$f" && grep -Eq "ansible_fqdn|inventory_hostname" "$f" && grep -q "ansible_hostname" "$f"' _ "$BASE"

# T13 — 10
task "TASK 13 — ANSIBLE VAULT VARIABLES (10)"
check "vault.yml exists and is encrypted" 3 bash -c 'test -f "$1/vault.yml" && head -1 "$1/vault.yml" | grep -q "ANSIBLE_VAULT"' _ "$BASE"
check "secret.txt exists with restrictive permissions" 2 bash -c 'test -f "$1/secret.txt" && test "$(stat -c %a "$1/secret.txt")" = 600' _ "$BASE"
check "vault.yml decrypts with secret.txt" 3 ansible-vault view "$BASE/vault.yml" --vault-password-file "$BASE/secret.txt"
check "Decrypted vault contains both required variable names" 2 bash -c 'ansible-vault view "$1/vault.yml" --vault-password-file "$1/secret.txt" 2>/dev/null | grep -q "pw_developer" && ansible-vault view "$1/vault.yml" --vault-password-file "$1/secret.txt" 2>/dev/null | grep -q "pw_manager"' _ "$BASE"

# T14 — 25
task "TASK 14 — USERS FROM VARIABLE FILES (25)"
check "user_list.yml and users.yml exist" 3 bash -c 'test -f "$1/user_list.yml" && test -f "$1/users.yml"' _ "$BASE"
check "users.yml syntax checks and references both variable files" 4 bash -c 'ansible-playbook -i "$1/inventory" "$1/users.yml" --syntax-check >/dev/null && grep -q "user_list.yml" "$1/users.yml" && grep -q "vault.yml" "$1/users.yml"' _ "$BASE"
check "opsdev group exists on dev and test" 4 remote 'dev:test' "getent group opsdev >/dev/null"
check "opsmgr group exists on test" 3 remote test "getent group opsmgr >/dev/null"
check "users.yml has developer and manager when conditions" 3 bash -c 'grep -q "when:" "$1/users.yml" && grep -qi "developer" "$1/users.yml" && grep -qi "manager" "$1/users.yml"' _ "$BASE"
check "User tasks use SHA-512 password hashing" 3 bash -c 'grep -Eqi "password_hash|sha512|password.*\\$6\\$" "$1/users.yml"' _ "$BASE"
check "At least one opsdev member exists on dev/test" 3 remote 'dev:test' "getent group opsdev | cut -d: -f4 | grep -q '[^,]'"
check "At least one opsmgr member exists on test" 2 remote test "getent group opsmgr | cut -d: -f4 | grep -q '[^,]'"

# T15 — 10
task "TASK 15 — REKEY SOLARIS VAULT (10)"
check "solaris.yml exists" 2 test -f "$BASE/solaris.yml"
check "solaris.yml decrypts with new password redhat" 6 bash -c 'printf "redhat\n" > "$1/newpass"; chmod 600 "$1/newpass"; ansible-vault view "$2/solaris.yml" --vault-password-file "$1/newpass" >/dev/null 2>&1' _ "$TMP" "$BASE"
check "solaris.yml no longer decrypts with old password cisco" 2 bash -c 'printf "cisco\n" > "$1/oldpass"; chmod 600 "$1/oldpass"; ! ansible-vault view "$2/solaris.yml" --vault-password-file "$1/oldpass" >/dev/null 2>&1' _ "$TMP" "$BASE"

# T16 — 10
task "TASK 16 — CRON JOB (10)"
check "crontab.yml exists and syntax checks" 2 bash -c 'test -f "$1/crontab.yml" && ansible-playbook -i "$1/inventory" "$1/crontab.yml" --syntax-check >/dev/null' _ "$BASE"
check "Student cron entry exists on all nodes" 3 remote all "crontab -u student -l 2>/dev/null | grep -q 'EX294 in progress'"
check "Cron schedule is every two minutes" 3 remote all "crontab -u student -l 2>/dev/null | grep -E '^[[:space:]]*\\*/2[[:space:]]+\\*[[:space:]]+\\*[[:space:]]+\\*[[:space:]]+\\*'"
check "Cron command uses logger with exact message" 2 remote all "crontab -u student -l 2>/dev/null | grep -E 'logger.*EX294 in progress'"

# T17 — 25
task "TASK 17 — LVM (25)"
check "lvm.yml exists and syntax checks" 3 bash -c 'test -f "$1/lvm.yml" && ansible-playbook -i "$1/inventory" "$1/lvm.yml" --syntax-check >/dev/null' _ "$BASE"
check "lvm.yml contains both required debug messages" 3 bash -c 'grep -q "vg not found" "$1/lvm.yml" && grep -q "Insufficient size of vg" "$1/lvm.yml"' _ "$BASE"
check "VG research exists on all nodes" 3 remote all "vgs research >/dev/null 2>&1"
check "LV research/data exists on all nodes" 4 remote all "lvs research/data >/dev/null 2>&1"
check "LV is 1500M or at least 800M" 5 remote all "size=\$(lvs --noheadings --units m --nosuffix -o lv_size research/data 2>/dev/null | awk '{print int(\$1)}'); test -n \"\$size\" && test \"\$size\" -ge 800"
check "LV filesystem is ext3" 5 remote all "dev=\$(lvs --noheadings -o lv_path research/data 2>/dev/null | xargs); test -n \"\$dev\" && test \"\$(blkid -o value -s TYPE \"\$dev\" 2>/dev/null)\" = ext3"
check "LV is not mounted" 2 remote all "dev=\$(lvs --noheadings -o lv_path research/data 2>/dev/null | xargs); ! findmnt -rn -S \"\$dev\" >/dev/null 2>&1"

# Result
log ""
log "============================================================"
log "FINAL RESULT"
log "============================================================"
log "Student: $STUDENT"
log "Total: $TOTAL/$MAX"
log "Pass mark: $PASS"
if (( TOTAL >= PASS )); then RESULT=PASS; else RESULT=FAIL; fi
log "Result: $RESULT"
log "Report: $REPORT"
echo ""
echo "============================================================"
echo "TOTAL: $TOTAL/$MAX    PASS MARK: $PASS    RESULT: $RESULT"
echo "Report: $REPORT"
echo "============================================================"
