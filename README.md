![Ansible](https://img.shields.io/badge/Ansible-2.9+-red.svg?logo=ansible\&logoColor=white) ![PHP: 8.1+](https://img.shields.io/badge/php-8.1+-orange) ![MediaWiki: 1.45.x](https://img.shields.io/badge/mediawiki-1.45.x-blue) ![Security](https://img.shields.io/badge/security-high-red) ![License: MIT](https://img.shields.io/badge/license-MIT-blue)

# MediaWiki Ansible Setup

## Übersicht

Dieses Repository enthält ein **professionelles Bash-Skript**, das **MediaWiki automatisch auf einem Linux-System installiert, aktualisiert und konfiguriert**, einschließlich aller gängigen Erweiterungen. Es nutzt **Ansible**, um Aufgaben wie das Herunterladen, Entpacken, Installieren von Extensions, Composer-Update, DB-Upgrade und Rechteverwaltung zu automatisieren.

## Features

* Automatische Installation von MediaWiki **Version 1.45.x**
* Nutzung von **Ansible Rollen** für modulare Aufgaben
* Sichern und Wiederherstellen von:

  * `LocalSettings.php`
  * `images`-Verzeichnis
* Automatische Installation und Aktualisierung von **34 MediaWiki-Extensions**
* Unterstützung für **PHP 8.1+**
* DB-Upgrade via `php maintenance/run.php update`
* Rechte-Management für alle MediaWiki-Dateien (www-data)
* Minimaler Eingriff erforderlich, Vollautomatisierung

## Voraussetzungen

* Ubuntu/Debian-basiertes System
* Root-Zugriff (sudo)
* Internetverbindung für Downloads
* Es werden automatisch installiert, falls nicht vorhanden:

  * ansible
  * unzip
  * git
  * composer
  * python3-pymysql

## Installation

Skript ausführen:

```bash
bash ./run_setup.sh
```

Das Skript:

* überprüft PHP-Version
* installiert System- und PHP-Pakete
* lädt MediaWiki herunter (tar.gz)
* sichert bestehende `LocalSettings.php` und `images`
* installiert oder aktualisiert Extensions
* führt Composer-Update aus
* aktualisiert die Datenbank
* setzt Rechte auf `www-data`

## Konfiguration

Standardwerte können im Skript in der `defaults/main.yml` angepasst werden:

* `mw_version`: MediaWiki Version
* `mw_major`: Major Version
* `mw_dir`: Zielverzeichnis der MediaWiki-Installation
* `extensions_dir`: Zielverzeichnis der Extensions
* `mediawiki_extensions_prune`: Entfernt nicht gewünschte Extensions
* `mw_extension_version`: Version aller Extensions (REL1_45)

## Erweiterungen

Das Skript installiert automatisch die folgenden Extensions:

* AbuseFilter, CategoryTree, CheckUser, Cite, CiteThisPage, CodeEditor
* ConfirmEdit, DiscussionTools, Echo, Gadgets, ImageMap, InputBox
* Linter, LoginNotify, Math, MultimediaViewer, Nuke, OATHAuth, PageImages
* ParserFunctions, PdfHandler, Poem, ReplaceText, Scribunto, SecureLinkFixer
* SpamBlacklist, SyntaxHighlight_GeSHi, TemplateData, TemplateStyles
* TextExtracts, Thanks, TitleBlacklist, VisualEditor, WikiEditor

## Sicherheit

* Rechte werden rekursiv auf `www-data:www-data` gesetzt
* Wartungsmodus wird während Updates automatisch aktiviert

## Vorteile

* **Zeitersparnis**: Vollautomatische Installation von MediaWiki inkl. Extensions
* **Reproduzierbarkeit**: Immer gleiche Umgebung dank Ansible
* **Wartbarkeit**: Modulare Rollen für einfache Updates
* **Sicherheit**: Richtige Dateirechte, DB-Update, Wartungsmodus

## Lizenz

Dieses Skript steht unter MIT-Lizenz.

## Support / Issues

Für Fragen, Feature Requests oder Bugs bitte im GitHub-Issue-Tracker melden.
