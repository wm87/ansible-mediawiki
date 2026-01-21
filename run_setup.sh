#!/bin/bash
set -euo pipefail

########################################
# Voraussetzungen
########################################
if ! command -v ansible-playbook >/dev/null 2>&1; then
	echo "Installiere Ansible..."
	apt-get update
	apt-get install -y ansible unzip git composer python3-pymysql
fi

########################################
# Arbeitsverzeichnis
########################################
WORKDIR=$(mktemp -d)
trap "rm -rf $WORKDIR" EXIT

ROLE_DIR="$WORKDIR/roles/mediawiki"
PLAYBOOK_DIR="$WORKDIR/playbook"

mkdir -p \
	"$ROLE_DIR"/{tasks,vars,defaults,handlers} \
	"$PLAYBOOK_DIR"

########################################
# Defaults
########################################
cat <<'EOF' >"$ROLE_DIR/defaults/main.yml"
mw_version: "1.45.1"
mw_major: "1.45"
mw_extension_version: "REL1_45"
mw_dir: "/var/lib/mediawiki_job"
extensions_dir: "/var/lib/mediawiki_job/extensions"
mediawiki_extensions_prune: true

mediawiki_extensions:
EOF

# Liste der Extensions
EXTENSIONS=(
	AbuseFilter CategoryTree CheckUser Cite CiteThisPage CodeEditor ConfirmEdit DiscussionTools Echo
	Gadgets ImageMap InputBox Linter LoginNotify Math MultimediaViewer Nuke OATHAuth PageImages
	ParserFunctions PdfHandler Poem ReplaceText Scribunto SecureLinkFixer SpamBlacklist
	SyntaxHighlight_GeSHi TemplateData TemplateStyles TextExtracts Thanks TitleBlacklist
	VisualEditor WikiEditor
)

for ext in "${EXTENSIONS[@]}"; do
	cat <<EOF >>"$ROLE_DIR/defaults/main.yml"
  - name: $ext
    repo: https://github.com/wikimedia/mediawiki-extensions-$ext.git
    version: "{{ mw_extension_version }}"
EOF
done

########################################
# MediaWiki data sichern (LocalSettings + images)
########################################
cat <<'EOF' >"$ROLE_DIR/tasks/data_pre.yml"
- name: Prüfen ob LocalSettings.php existiert
  stat:
    path: "{{ mw_dir }}/LocalSettings.php"
  register: mw_localsettings

- name: Alte /tmp/LocalSettings.php entfernen
  file:
    path: /tmp/LocalSettings.php
    state: absent
  when: mw_localsettings.stat.exists

- name: LocalSettings.php nach /tmp verschieben
  command: mv "{{ mw_dir }}/LocalSettings.php" /tmp/LocalSettings.php
  when: mw_localsettings.stat.exists

- name: Prüfen ob images-Verzeichnis existiert
  stat:
    path: "{{ mw_dir }}/images"
  register: mw_images

- name: Altes /tmp/images entfernen
  file:
    path: /tmp/images
    state: absent
  when: mw_images.stat.exists

- name: Images nach /tmp verschieben
  command: mv "{{ mw_dir }}/images" /tmp/images
  when: mw_images.stat.exists
EOF

########################################
# MediaWiki data zurückspielen
########################################
cat <<'EOF' >"$ROLE_DIR/tasks/data_post.yml"
- name: Prüfen ob gesicherte LocalSettings existiert
  stat:
    path: /tmp/LocalSettings.php
  register: tmp_localsettings

- name: LocalSettings.php zurück nach MediaWiki verschieben
  command: mv /tmp/LocalSettings.php "{{ mw_dir }}/LocalSettings.php"
  when: tmp_localsettings.stat.exists

- name: Prüfen ob gesicherte images existieren
  stat:
    path: /tmp/images
  register: tmp_images

- name: Images zurück nach MediaWiki verschieben
  command: mv /tmp/images "{{ mw_dir }}/images"
  when: tmp_images.stat.exists
EOF

########################################
# Playbook
########################################
cat <<'EOF' >"$PLAYBOOK_DIR/site.yml"
---
- hosts: localhost
  connection: local
  become: true

  roles:
    - mediawiki
EOF

########################################
# Vars
########################################
cat <<'EOF' >"$ROLE_DIR/vars/main.yml"
php_packages:
  - php
  - php-mysql
  - php-xml
  - php-mbstring
EOF

########################################
# Tasks main
########################################
cat <<'EOF' >"$ROLE_DIR/tasks/main.yml"
- import_tasks: packages.yml
- import_tasks: data_pre.yml
- import_tasks: download.yml
- import_tasks: data_post.yml
- import_tasks: preflight.yml
- import_tasks: extensions.yml
- import_tasks: composer.yml
- import_tasks: fix_permissions.yml
EOF

########################################
# Packages
########################################
cat <<'EOF' >"$ROLE_DIR/tasks/packages.yml"
- name: Systempakete installieren
  apt:
    update_cache: yes
    name:
      - apache2
      - mysql-server
      - unzip
      - git
      - composer
      - python3-pymysql

- name: PHP Pakete installieren
  apt:
    name: "{{ php_packages }}"
EOF

########################################
# MediaWiki Download (tar.gz)
########################################
cat <<'EOF' >"$ROLE_DIR/tasks/download.yml"
- name: MediaWiki Tarball herunterladen
  get_url:
    url: "https://releases.wikimedia.org/mediawiki/{{ mw_major }}/mediawiki-{{ mw_version }}.tar.gz"
    dest: "/tmp/mediawiki-{{ mw_version }}.tar.gz"
    mode: '0644'

- name: MediaWiki Tarball entpacken
  unarchive:
    src: "/tmp/mediawiki-{{ mw_version }}.tar.gz"
    dest: "/tmp/"
    remote_src: yes

- name: MediaWiki Zielverzeichnis sicherstellen
  file:
    path: "{{ mw_dir }}"
    state: directory
    mode: '0755'

- name: MediaWiki Dateien per rsync kopieren
  synchronize:
    src: "/tmp/mediawiki-{{ mw_version }}/"
    dest: "{{ mw_dir }}/"
    delete: yes
    recursive: yes
  delegate_to: localhost
EOF

########################################
# Preflight
########################################
cat <<'EOF' >"$ROLE_DIR/tasks/preflight.yml"
- name: PHP Version prüfen
  command: php -r 'echo PHP_VERSION;'
  register: php_version
  changed_when: false

- name: PHP Version validieren
  assert:
    that:
      - php_version.stdout is version('8.1', '>=')
    fail_msg: "PHP Version {{ php_version.stdout }} nicht kompatibel"

- name: Wartungsmodus aktivieren
  file:
    path: "{{ mw_dir }}/.maintenance"
    state: touch
EOF

########################################
# Extensions
########################################
cat <<'EOF' >"$ROLE_DIR/tasks/extensions.yml"
- name: Extensions-Verzeichnis sicherstellen
  file:
    path: "{{ extensions_dir }}"
    state: directory
    mode: '0755'

- name: Alte nicht-Git Extensions entfernen
  file:
    path: "{{ extensions_dir }}/{{ item.name }}"
    state: absent
  loop: "{{ mediawiki_extensions }}"
  when: >
    not lookup('ansible.builtin.fileglob',
               extensions_dir + '/' + item.name + '/.git',
               errors='ignore')

- name: Extensions installieren / upgraden (Git)
  git:
    repo: "{{ item.repo }}"
    dest: "{{ extensions_dir }}/{{ item.name }}"
    version: "{{ item.version }}"
    update: yes
    force: yes
  loop: "{{ mediawiki_extensions }}"

- name: Erlaubte Extensions setzen
  set_fact:
    allowed_extensions: "{{ mediawiki_extensions | map(attribute='name') | list }}"

- name: Nicht gewünschte Extensions entfernen
  find:
    paths: "{{ extensions_dir }}"
    file_type: directory
    depth: 1
  register: found_extensions

- file:
    path: "{{ item.path }}"
    state: absent
  loop: "{{ found_extensions.files }}"
  when:
    - mediawiki_extensions_prune
    - item.path | basename not in allowed_extensions
EOF

########################################
# Composer & DB Update
########################################
cat <<'EOF' >"$ROLE_DIR/tasks/composer.yml"
- name: Composer Update
  shell: |
    composer update
    composer require wikimedia/equivset --update-with-dependencies
  args:
    chdir: "{{ mw_dir }}"

- name: Prüfen ob LocalSettings.php existiert
  stat:
    path: "{{ mw_dir }}/LocalSettings.php"
  register: mw_localsettings

- name: MediaWiki DB Update
  shell: php maintenance/run.php update
  args:
    chdir: "{{ mw_dir }}"
  when: mw_localsettings.stat.exists

- name: Wartungsmodus deaktivieren
  file:
    path: "{{ mw_dir }}/.maintenance"
    state: absent
EOF

########################################
# Berechtigungen für das komplette MediaWiki-Verzeichnis
########################################
cat <<'EOF' >"$ROLE_DIR/tasks/fix_permissions.yml"
- name: Eigentümer und Rechte für MediaWiki setzen
  file:
    path: "{{ mw_dir }}"
    owner: www-data
    group: www-data
    recurse: yes
EOF

########################################
# Handler
########################################
cat <<'EOF' >"$ROLE_DIR/handlers/main.yml"
- name: restart apache
  service:
    name: apache2
    state: restarted
EOF

########################################
# Ausführung
########################################
ANSIBLE_ROLES_PATH="$WORKDIR/roles" \
	ansible-playbook \
	-i localhost, \
	-c local \
	"$PLAYBOOK_DIR/site.yml"
