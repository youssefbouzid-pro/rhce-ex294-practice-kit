# RHCE EX294 Practice Kit

This kit contains:
- `index.html`: browser-based exam dashboard with all 17 tasks, checklist, 4-hour timer, local progress persistence and a weighted estimate. Task text and key values follow the supplied question sheet; the overview also lists the lab credentials, paths and the practice-only `research` volume-group setup.
- `rhce-validator.sh`: Bash validation script for the Ansible control node. It grades the lab state out of 300 (pass mark 210) and writes a timestamped report.

## Web app
Open `index.html` in a browser. It works locally and does not need a web server. Enter the candidate's full name on the overview screen, then click **Start Examination** (or press Enter in the name field). The name appears in the exam header and completion summary. Progress is saved in that browser's local storage.

## Validator prerequisites
Run on `workstation.lab.example.com` as the control-node user (normally `student`):
- Ansible installed and configured
- `/home/student/ansible/inventory`
- `/home/student/ansible/ansible.cfg`
- SSH connectivity from control node to managed nodes
- `devops` remote user (override with `ANSIBLE_REMOTE_USER`)
- become/root password `redhat`
- `curl` available on managed nodes for HTTP checks

Run:
```bash
chmod +x rhce-validator.sh
./rhce-validator.sh
```

By default the script expects the project at `$HOME/ansible`. The report is saved under `$HOME/grading-reports/`.

## Important assumptions and caveats
1. The task sheet does not provide per-task marks. The validator uses a suggested rubric totalling 300; it is not an official Red Hat scoring scheme.
2. Some checks depend on the task's exact lab environment, role defaults and content. A role implementation can be correct but fail a strict check if it uses a different valid path or service arrangement.
3. Task 6 is internally inconsistent: the inventory puts `servera` in `dev` and only `serverc` in `webservers` (because `prod` is a child group). The task nevertheless gives a servera PHP/web example. The grader checks the coherent inventory-based serverc/webservers requirement and checks servera only through the apache/dev task.
4. Task 9 says SELinux context type `httpd`; on RHEL the usual file type is `httpd_sys_content_t` (or `httpd_sys_rw_content_t` when writes are required). The validator accepts either.
5. Task 12 specifies 172.25.250.10–13 while task 1's inventory specifies 10.0.20.2–5. The grader checks the explicit `/etc/myhosts` example values. Adjust if your actual lab uses the inventory addresses instead.
6. User password validation checks account/group presence and SHA-512 shadow hash format; it does not attempt to authenticate with plaintext passwords.
7. The hardware report check verifies required keys and non-empty values; it does not enforce a particular memory/disk unit because the task sheet does not specify one.
8. The LVM check accepts an LV of at least 800 MiB and ext3, and verifies it is not mounted. The debug output itself cannot be proven from final host state; the script checks the messages in `lvm.yml`.
9. Remote checks assume the inventory groups are named `all`, `dev`, `test`, and `prod`, and that the `balancers` group contains serverd. If your inventory uses a different group layout, update the script.
10. Task 11's question sheet spells the dev banner `Developement`; the validator currently expects `Development`. The dashboard notes both spellings so the mismatch is visible while practising.

## Security
The uploaded sample grader contained a Telegram bot token and chat ID. Treat that token as exposed: revoke/regenerate it with BotFather and do not reuse it. This RHCE validator intentionally does not include Telegram reporting or any embedded credentials.
