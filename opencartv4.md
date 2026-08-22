
# OpenCart 4 — The Complete Developer's Learning Document (4.0.x & 4.1.x)

*A single, exhaustive, hands-on reference for a fresher/junior PHP developer who needs to master OpenCart 4 end-to-end: theme customization, theme creation, extension customization, extension creation, performance, and contributing to the core GitHub repository. Written for the latest 4.x line (4.1.x, current build 4.1.0.4) and cross-referenced against 4.0.x.*

## TL;DR
- **OpenCart 4 is a ground-up modernization of the PHP MVC-L e-commerce framework.** It requires **PHP 8.0 minimum** (PHP 8.1+ strongly recommended; 4.1.0.4 adds PHP 8.5 support), introduces full `Opencart\` **namespaces** with PSR-4-style autoloading, moves all third-party code into a top-level **`extension/`** directory, packages add-ons as **`.ocmod.zip`** with an **`install.json`**, uses **Twig `.twig`** templates, and favors the **database-backed Event system** over the old OCMOD/vQmod file-patching. Consequently **nearly every OpenCart 3 tutorial online will break if copied verbatim** — the class syntax, file paths, event separators, and admin form pattern all changed.
- **To master it, learn in this order:** the request lifecycle (`index.php → system/startup.php → system/framework.php → Router → Action → Controller`) → the engine classes (Registry, Loader, Action, Factory, Proxy, Event) → the Event system → theme overriding via a theme extension + a `view/*/before` event → extension anatomy (admin+catalog+system, `install()/uninstall()`, settings via `model_setting_setting`) → performance (theme cache, image cache, Redis/Memcached drivers, OPcache, disabling category counts) → the GitHub contribution workflow.
- **Contributing to core is realistic for a diligent junior.** The repo has **no PHPUnit test suite** — quality is enforced purely by the `Lint.yml` CI (PHP syntax lint, PHPStan level 6, php-cs-fixer). PRs target **`master`**, which per the README "will always contain an `_rc` postfix of the next intended version." Commits must be focused and follow the coding standard (tabs in PHP, 2-space in Twig, 1TBS braces, camelCase methods, snake_case variables), and translations must go through **Crowdin**, not PRs.

---

## Table of Contents
1. Foundations
2. Framework Architecture (deep dive)
3. Themes
4. Extensions
5. Performance
6. Contributing to OpenCart Core
7. Practical Learning Path, Glossary & Troubleshooting

---

# 1. Foundations

## 1.1 What OpenCart 4 is
OpenCart is a free, open-source PHP e-commerce platform developed by OpenCart Limited (Hong Kong), first released April 2010, created by Daniel Kerr. It is licensed under the **GNU General Public License v3 (GPLv3)** (`license.txt` in the repo). It uses a MySQLi/PDO (MySQL, MariaDB, Percona) or PostgreSQL database and follows a custom **MVC-L (Model-View-Controller-Language)** architecture. OpenCart 4 is a major architectural rewrite versus OpenCart 3: same visual "skin" by default, but a very different engine underneath — which is exactly why it can look deceptively similar while breaking OC3 extensions.

## 1.2 Version history & 4.0 vs 4.1
- **4.0.0.0** — first OC4 release, **published 24 May 2022**. The 4.0.x line was buggy; through 2022–2024 developers widely recommended staying on the stable 3.0.x branch for production.
- **4.0.2.3** (Sept 2023) — the most usable 4.0 build.
- **4.1.0.0** (January 2025) — the current 4.x line. Two core changes break some 4.0 extensions:
  - **The event method separator changed from `/` to `.`** — e.g. `catalog/controller/checkout/payment_method.save/after`. This is the single most common 4.0→4.1 breakage.
  - **Product `sku`, `upc`, `ean`, `jan`, `isbn`, `mpn` fields were relocated to a new `oc_product_code` table.**
- **4.1.0.3** (24 March 2025) — fixes the upgrade procedure (#14703), fixes the extension installer, and does a large PHPDoc/comment cleanup (many PRs by @TheCartpenter).
- **4.1.0.4 / 3.0.5.1** (11 August 2026) — bug-fix roll-ups that officially add **PHP 8.5 support**. (PHP 8.5 was released 20 November 2025, per php.net: "Released Nov 20, 2025 · PHP 8.5 is a major update of the PHP language.")

> **Practical guidance:** learn on the latest 4.1.x. Use the GitHub `master` branch only for experimentation/contribution, never production. Note that many community members still consider 3.0.x more "battle-tested" and extension-rich — but 4.x is where the platform is evolving, and it is the correct target for new learning.

## 1.3 Licensing (GPLv3)
Everything that includes OpenCart core code is bound by GPLv3. You may sell extensions/themes on the OpenCart marketplace, but you must respect the copyleft terms for distributed derivative works.

## 1.4 System requirements
| Component | Requirement |
|---|---|
| **PHP** | **8.0 minimum** (`system/startup.php` enforces `PHP_VERSION` ≥ 8.0.0). 4.0.0 practically needed 8.1. **8.1+ recommended**; 4.1.0.4 supports up to 8.5. |
| **Database** | MySQLi, PDO (MySQL driver), or PostgreSQL. MySQL/MariaDB/Percona supported; **MySQLi recommended**. |
| **Web server** | Apache 2.x (recommended), Nginx, or IIS. |
| **Required PHP extensions** | Curl, GD, ZIP, plus standard MBString/OpenSSL/JSON. The installer checks these on the Pre-Installation step. |
| **Recommended php.ini (large stores)** | `memory_limit = 256M+`, `upload_max_filesize = 20M+`, `post_max_size = 20M+`, `max_execution_time = 300`, `max_input_vars = 5000+` (raise for products with many options/categories, or storing/saving fails silently). |

## 1.5 Installation (manual)
1. Download the release zip from opencart.com (end users) or clone GitHub (developers). **Only the `upload/` folder's contents are the actual store files**; `license.txt` and `readme.txt` sit beside it.
2. Upload the **contents of `upload/`** to your webroot (`public_html`) — not the `upload/` folder itself (else the store lands at `/upload`).
3. **Rename `config-dist.php` → `config.php`** and `admin/config-dist.php` → `admin/config.php`.
4. Create a MySQL/MariaDB database + user with full privileges.
5. Browse to the site; the installer (`install/` folder) auto-launches: **License → Pre-Installation checks → Configuration (DB details + admin account) → Finished.**
6. **Delete the `install/` directory** after finishing.
7. Rename the `admin/` directory to something non-obvious (the installer offers a field for this) and use a strong admin password.

### Security hardening: relocate `storage/` outside the webroot
The `system/storage/` folder holds cache, logs, sessions, downloads, uploads, the modification cache, and the Composer `vendor/` — it can leak sensitive data if publicly readable. OC4's admin dashboard provides a **one-click "move storage" tool** (Dashboard → gear/Developer Settings). After moving, `DIR_STORAGE` in both config files points outside the docroot.

### Local dev environments
- **XAMPP / Laragon (Windows)**, **MAMP (macOS)**, **LAMP (Linux)** all work.
- **Docker** is the officially-blessed contributor path: the core repo ships a `docker-compose.yml`, a `docker/` folder, and a `Makefile` with `make init`, `make build`, `make up`, `make php`, `make logs`, `make down`.

### Enabling debug / error reporting
- **Admin → System → Settings → Server tab**: turn **Error Logging** on, and during development set **Display Errors** on. Errors are written to `system/storage/logs/` (`error.log`).
- **Developer Settings** (Dashboard gear icon): toggle **Theme cache** and **SASS/SCSS compilation**, and use **Clear Cache** / **Clear Theme & SASS Cache** — you will click this constantly while developing.

## 1.6 `config.php` and `admin/config.php` explained
Two near-identical files. The **root `config.php`** serves the catalog (storefront); **`admin/config.php`** serves the admin. Each defines URL and absolute-path constants plus DB credentials. Typical OC4 root `config.php`:

```php
<?php
// HTTP
define('HTTP_SERVER', 'https://www.yourstore.com/');       // storefront base URL

// HTTPS (OC4 assumes HTTPS)
define('HTTPS_SERVER', 'https://www.yourstore.com/');

// DIR
define('DIR_APPLICATION', '/var/www/html/catalog/');       // which app: catalog/ or admin/
define('DIR_SYSTEM', '/var/www/html/system/');
define('DIR_IMAGE', '/var/www/html/image/');
define('DIR_STORAGE', DIR_SYSTEM . 'storage/');            // point OUTSIDE webroot in prod
define('DIR_LANGUAGE', DIR_APPLICATION . 'language/');
define('DIR_TEMPLATE', DIR_APPLICATION . 'view/template/'); // OC4: was view/theme/ in OC3
define('DIR_CONFIG', DIR_SYSTEM . 'config/');
define('DIR_CACHE', DIR_STORAGE . 'cache/');
define('DIR_DOWNLOAD', DIR_STORAGE . 'download/');
define('DIR_LOGS', DIR_STORAGE . 'logs/');
define('DIR_SESSION', DIR_STORAGE . 'session/');
define('DIR_UPLOAD', DIR_STORAGE . 'upload/');
define('DIR_MODIFICATION', DIR_STORAGE . 'modification/'); // OCMOD virtual-file cache

// DB
define('DB_DRIVER', 'mysqli');      // mysqli | pdo (mpdo) | pgsql
define('DB_HOSTNAME', 'localhost');
define('DB_USERNAME', 'dbuser');
define('DB_PASSWORD', 'dbpass');
define('DB_DATABASE', 'opencart');
define('DB_PORT', '3306');
define('DB_PREFIX', 'oc_');         // every table name is prefixed with this

// (optional) CACHE driver constants — see §5
// define('CACHE_DRIVER', 'redis');
```

- **`admin/config.php`** differs by pointing `DIR_APPLICATION` at `admin/`, `DIR_TEMPLATE` at `admin/view/template/`, and adds `HTTP_CATALOG`/`HTTPS_CATALOG` (so the admin can build storefront links) and `define('DIR_CATALOG', ...)`.
- `DB_DRIVER` values: `mysqli`, `pdo`/`mpdo` (MySQL via PDO), `pgsql`. **Install with MySQLi, then optionally switch to `mpdo`** — a common gotcha is "Could not load DB adaptor pdo," fixed by installing under mysqli first.

## 1.7 Complete directory structure walkthrough
```
(webroot)/
├── index.php              # storefront front controller → start('catalog')
├── config.php             # storefront config
├── admin/
│   ├── index.php          # admin front controller → start('admin')
│   ├── config.php         # admin config
│   ├── controller/        # admin controllers (common/, catalog/, sale/, ...)
│   ├── model/             # admin models
│   ├── view/
│   │   ├── template/      # admin Twig templates
│   │   ├── stylesheet/    # admin CSS
│   │   ├── javascript/    # admin JS
│   │   └── image/
│   └── language/          # admin language packs (en-gb/, ...)
├── catalog/
│   ├── controller/        # storefront controllers
│   ├── model/             # storefront models
│   ├── view/
│   │   ├── template/      # storefront Twig templates (default theme)
│   │   ├── javascript/
│   │   └── stylesheet/
│   └── language/
├── extension/             # ★ NEW in OC4: ALL add-ons live here
│   ├── opencart/          # OpenCart's own bundled extensions (payments, modules, theme…)
│   └── <your_vendor>/     # each installed .ocmod.zip creates a folder here
├── system/
│   ├── startup.php        # bootstrap: constants, autoloader, error handler
│   ├── framework.php      # wires Registry, Config, DB, Event, Loader, Request/Response…
│   ├── engine/            # core classes: registry, loader, action, controller, model,
│   │                      #   config, event, factory, autoloader, proxy
│   ├── config/            # default.php, catalog.php, admin.php (framework config arrays)
│   ├── helper/            # procedural helpers (general, utf8, json, …)
│   ├── library/           # services: db/, cache/, cart/, customer, user, currency,
│   │                      #   tax, session/, template/, mail/, image, request, response…
│   └── storage/           # (relocate outside webroot) cache/ logs/ session/
│                          #   download/ upload/ modification/ vendor/ marketplace/
├── image/                 # product/catalog images + image/cache/ (resized copies)
└── install/               # installer (DELETE after install)
```
Two applications (**catalog** + **admin**) share **system/**. Every route resolves into one of the two application trees.

**Further reading (§1):** docs.opencart.com/getting-started/installation · docs.opencart.com/getting-started/system-requirements · github.com/opencart/opencart/wiki/OpenCart-Basics

---

# 2. Framework Architecture (deep dive)

## 2.1 MVC-L pattern
OpenCart splits every feature into four files that mirror each other by route:
- **Controller** (`.../controller/<path>.php`) — orchestrates: loads models, loads language, assembles `$data`, renders a view.
- **Model** (`.../model/<path>.php`) — all DB access and business data logic.
- **View** (`.../view/template/<path>.twig`) — Twig presentation.
- **Language** (`.../language/en-gb/<path>.php`) — a PHP file of `$_['key'] = 'text';` entries.

The "L" (Language) is what distinguishes OpenCart's flavour from vanilla MVC. (The core CONTRIBUTING guide sometimes calls it "MVC-A," bundling controller/model/view/language.)

## 2.2 Bootstrap / request lifecycle (step by step)
For a storefront request `index.php?route=product/category`:

1. **`index.php`** requires `config.php`, then `system/startup.php`, then calls `start('catalog')`.
2. **`system/startup.php`** — defines `APPLICATION`, sets error/exception handlers, registers the autoloader:
   ```php
   require_once(DIR_SYSTEM . 'engine/autoloader.php');
   $autoloader = new \Opencart\System\Engine\Autoloader();
   $autoloader->register('Opencart\\' . APPLICATION, DIR_APPLICATION);
   $autoloader->register('Opencart\\System', DIR_SYSTEM);
   ```
   It also loads global helper functions and the Composer autoloader from `system/storage/vendor/`.
3. **`start()` → `system/framework.php`** builds the object graph and stores everything in the Registry:
   - `Registry` created;
   - `Config` loaded (`system/config/default.php` + `catalog.php`/`admin.php`);
   - `Event` engine created and set; active DB events/routes registered:
     ```php
     $event->register($key, new \Opencart\System\Engine\Action($action), $priority);
     $registry->set('factory', new \Opencart\System\Engine\Factory($registry));
     $loader = new \Opencart\System\Engine\Loader($registry); $registry->set('load', $loader);
     $request = new \Opencart\System\Library\Request(); $registry->set('request', $request);
     ```
   - **Route compatibility shim:** `$request->get['route'] = str_replace('|', '.', $request->get['route']);` — this is why some tutorials use `|` and others `.` as the method separator.
   - `Response`, `Session`, `Cache`, `Document`, `Language`, `DB`, `Url`, `Template`, plus catalog services (`Cart`, `Customer`/`User`, `Currency`, `Tax`, `Weight`, `Length`) instantiated and registered.
4. **Front controller / Router** reads `route` (default `common/home` on storefront), then runs the **pre-action → action → post-action** pipeline.
5. **`Action->execute()`** instantiates the controller and calls the method:
   ```php
   // system/engine/action.php
   $output = call_user_func_array([$controller, $this->method], $args);
   ```
6. Controller renders a Twig view into the `Response`; `Response->output()` sends headers + body.

The admin lifecycle is identical but bootstraps `admin/config.php`, adds the `user_token` auth/permission startup, and routes default to the dashboard.

## 2.3 Registry pattern & dependency container
`system/engine/registry.php` is a tiny service container:
```php
namespace Opencart\System\Engine;
class Registry {
    private array $data = [];
    public function get(string $key): mixed { return $this->data[$key] ?? null; }
    public function set(string $key, object $value): void { $this->data[$key] = $value; }
    public function has(string $key): bool { return isset($this->data[$key]); }
    // __get/__set magic delegate to get()/set()
}
```
Because `Controller` and `Model` implement magic `__get()` that proxies to the registry, `$this->db`, `$this->config`, `$this->load`, `$this->event`, `$this->request`, `$this->response`, `$this->session`, `$this->cart`, `$this->user`, `$this->url`, `$this->document`, `$this->language`, `$this->log` all resolve to registry entries. **OC4 does not remove the registry** — but you rarely call `$this->registry->get(...)` directly; the magic accessors are the idiomatic path. (This is what people mean by "removal of the `$this->registry` pattern" — direct registry calls are discouraged, not deleted.)

## 2.4 Autoloader & routing/namespaces
`system/engine/autoloader.php` maps namespace prefixes to directories. The key OC4 change is **namespaced classes**:
- Storefront controller for `product/category` →
  file `catalog/controller/product/category.php`,
  namespace `Opencart\Catalog\Controller\Product`,
  class `Category extends \Opencart\System\Engine\Controller`.
- Admin equivalent → `Opencart\Admin\Controller\...`.
- Extension controller → `Opencart\Catalog\Controller\Extension\<Vendor>\<Type>` in `extension/<vendor>/catalog/controller/<type>/<name>.php`.

> **OC3-only pattern that breaks in OC4:** OC3 used non-namespaced class names like `class ControllerProductCategory extends Controller` and `class ModelCatalogProduct extends Model`. In OC4 these become namespaced classes extending `\Opencart\System\Engine\Controller` / `\...\Model`. Copying an OC3 controller verbatim will fatal.

Route → path resolution: the last route segment is the file/class; a `.method` suffix selects the method (default `index`). `Action`'s constructor (from source):
```php
$this->route = preg_replace('/[^a-zA-Z0-9_|\/\.]/', '', $route);
$pos = strrpos($route, '.');
if ($pos !== false) { $this->controller = substr($route,0,$pos); $this->method = substr($route,$pos+1); }
else { $this->controller = $route; $this->method = 'index'; }
```
SEO URLs are handled by the `seo_url` startup + the `oc_seo_url` table, mapping keyword paths to `route=` queries.

## 2.5 Core engine classes (source-level)
| Class (`system/engine/…`) | Role / key methods |
|---|---|
| **Registry** | Service container: `get/set/has`, magic `__get/__set`. |
| **Autoloader** | `register($namespace, $directory)`; resolves `Opencart\...` classes to files, checking the modification cache first. |
| **Loader** | `controller()`, `model()`, `view()`, `language()`, `config()`, `helper()`, `library()`. Wraps each load in `*/before` and `*/after` events. |
| **Action** | Encapsulates a route → controller+method; `execute(Registry, &$args)` calls the method via `call_user_func_array`. |
| **Controller** | Base class; magic `__get` → registry. Extended by every controller. |
| **Model** | Base class for models; magic `__get` → registry. |
| **Config** | Loads/holds settings arrays: `get()`, `set()`, `has()`. |
| **Event** | `register($trigger, Action, $priority)`, `trigger($event, $args)`, `unregister()`. Publisher/subscriber. |
| **Factory** | Builds controller/model objects (used by Loader) so they can be proxied. |
| **Proxy** | Wrapper enabling method interception on models — the object from `$this->load->model()` is a Proxy whose `__call` fires `model/*/before` and `model/*/after` around the real method. |

### The Loader in detail
`Loader->controller($route, ...$args)` (from source):
```php
$route = preg_replace('/[^a-zA-Z0-9_\/]/', '', (string)$route);
$trigger = $route;
$result = $this->registry->get('event')->trigger('controller/'.$trigger.'/before', [&$route, &$args]);
// ... resolves Action, executes, then triggers 'controller/'.$trigger.'/after'
```
`Loader->model($route)` creates a key `model_<route with / → _>`, builds the object via the Factory (wrapped in a Proxy), verifies it is a `\Opencart\System\Engine\Model`, and stores it in the registry as `model_<path>` — so `$this->model_setting_setting`, `$this->model_catalog_product`, etc. become available. `view()` renders a Twig template and returns HTML. `language()` merges a language file's array into the Language service. `config()` merges a config file. `helper()` requires a procedural helper. `library()` instantiates a service into the registry (only libraries can be auto-loaded on demand).

## 2.6 The Event system (the modern extension backbone)
Events let you hook core without editing files. **Two ways to register:**

**A) Declaratively via the DB (`oc_event` table)** — in your extension's `install()`:
```php
$this->load->model('setting/event');
$this->model_setting_event->addEvent([
    'code'        => 'test_module_cart_add_before',            // unique id
    'description' => 'Log before cart add',
    'trigger'     => 'catalog/controller/checkout/cart.add/before',
    'action'      => 'extension/test_module/events.onCartAddBefore', // route.method of listener
    'status'      => 1,
    'sort_order'  => 1,
]);
// uninstall(): $this->model_setting_event->deleteEventByCode('test_module_cart_add_before');
```

**B) Programmatically at startup** (no reinstall needed while developing) — in `extension/<vendor>/catalog/controller/startup/<file>.php`:
```php
$this->event->register('view/*/before',
    new \Opencart\System\Engine\Action('extension/<vendor>/startup/<file>.event'));
```

**Trigger taxonomy** (`namespace/action/stage`):
- `controller/<route>/before` & `/after`
- `model/<route>/<method>/before` & `/after`
- `view/<route>/before` & `/after` (modify `$data` before render, or `$output` after)
- `language/<route>/after`

**Listener signatures:**
```php
// before: modify args by reference
public function onCartAddBefore(string &$route, array &$args, mixed &$output = null): void {}
// view/* : $data by reference on before; $output (rendered HTML) on after
public function event(string &$route, array &$args, mixed &$output): void {}
```
**Sort order / priority:** the numeric `sort_order` (DB) or the `$priority` arg (programmatic) controls execution order among multiple listeners on the same trigger.

> **OC3 → OC4.1 gotcha (critical):** In OC3, events used `/` separators like `.../cart/add/before`. In OC4.0 the method separator was commonly `|`. In **OC4.1 the method separator is `.`** (`cart.add`, `payment_method.save`). Also note: when referring to the `index` method, omit the method entirely (`product/product`, not `product/product.index`). Getting the separator wrong is the #1 reason a copied listener silently never fires. Verify **on your exact patch version**.

## 2.7 The Proxy class & model interception
`$this->load->model('catalog/product')` returns a **Proxy**, not the raw model. When you call `$this->model_catalog_product->getProduct($id)`, the Proxy's `__call` fires `model/catalog/product/getProduct/before`, runs the real method, then fires `.../after` — enabling extensions to alter model inputs/outputs without touching the model file. This is the mechanism behind OpenCart's non-invasive extensibility.

## 2.8 Database layer
`system/library/db.php` is a thin façade over a driver in `system/library/db/` (`mysqli.php`, `pdo.php`, `pgsql.php`), selected by `DB_DRIVER`. API:
```php
$query = $this->db->query("SELECT ...");  // returns object with ->row, ->rows, ->num_rows
$this->db->escape($string);               // driver-safe escaping (MUST wrap all string input)
$this->db->countAffected();
$this->db->getLastId();
```
The PDO driver connects with `charset=utf8mb4` and `SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci`. **Safe query rules:** cast integers `(int)$id`; wrap strings in `'" . $this->db->escape($val) . "'`; always prefix tables with a backtick + `DB_PREFIX`:
```php
$this->db->query("INSERT INTO `" . DB_PREFIX . "setting`
    SET `value` = '" . $this->db->escape($v) . "'");
```
Never concatenate raw user input — an unescaped value permits SQL injection. The Request class also applies `htmlspecialchars()` to incoming GET/POST (an XSS layer), but that is **not** a substitute for `escape()`. Transactions are available at driver level; wrap multi-statement writes accordingly. There is no built-in query builder — third-party ones exist but core uses raw parameterized-by-escaping SQL.

## 2.9 Key libraries (`system/library/`)
`cart` (contents/totals), `customer`/`user` (storefront/admin auth + `hasPermission`), `currency`, `tax`, `weight`, `length`, `session` (file/db/redis engines), `cache` (see §5), `log` (`$this->log->write(...)` → `error.log`), `mail`, `encryption`, `image` (resize/cache), `request`, `response`, `document` (title/meta/links/scripts), `template` (Twig adaptor), `url` (SEO link building).

## 2.10 Template engine (Twig)
OC4 uses **Twig** (`.twig`). The `Template` library (`system/library/template/`) has a Twig adaptor with `render($template, $cache)`. Controllers pass data via an array to `$this->load->view('route', $data)`; every `$data['x']` becomes `{{ x }}` in Twig. Syntax essentials: `{{ var }}` (auto-escaped), `{% if %}/{% for %}/{% endfor %}`, `{% include %}`, `{{ var|filter }}`. Compiled templates cache under `system/storage/cache/`; the theme-level cache is toggled in Developer Settings. **OC3 → OC4:** OC3 already used Twig, but OC4 relocated templates from `catalog/view/theme/<theme>/template/` to `catalog/view/template/` (default) and `extension/<theme>/catalog/view/template/` (theme extensions).

## 2.11 Language system
Language files are PHP returning `$_['key'] = 'value';`. In a controller: `$this->load->language('extension/test_module/module/test_module');` then `$this->language->get('heading_title')`. Folder structure: `.../language/en-gb/<path>.php`. Adding a language = adding an `en-gb`-parallel folder (e.g. `fr-fr/`) and installing the pack; OC4 also ships an admin **Language Editor**. Core translations must go through **Crowdin**, not PRs.

## 2.12 Settings / Config system
Store settings live in `oc_setting` (store-scoped via `store_id`). Read with `$this->config->get('config_name')` or extension keys like `module_test_module_status`. Write via the setting model:
```php
$this->load->model('setting/setting');
$this->model_setting_setting->editSetting('module_test_module', $this->request->post);
```
`editSetting($group, $data, $store_id = 0)` serializes each `$data` key into a row. Store-scoped settings enable OC's multi-store.

## 2.13 Permissions / user groups
Admin authorization uses `oc_user_group` (access + modify permission arrays) checked by:
```php
if (!$this->user->hasPermission('modify', 'extension/test_module/module/test_module')) {
    $json['error'] = $this->language->get('error_permission');
}
```
`access` gates viewing a page; `modify` gates saving.

## 2.14 Security model
- **`user_token`**: the admin CSRF/session token appended to every admin URL (`user_token=...`) and validated on each request — OC4's replacement/rename of OC3's `token`.
- **Permissions**: `hasPermission('access'|'modify', route)`.
- **Input**: `$this->db->escape()` for SQL; Request auto-`htmlspecialchars`.
- **API layer**: `oc_api` table + `api/` routes issue a session for programmatic access (used by the default checkout AJAX and external integrations).
- **Sessions**: `system/library/session/` with file/db/redis engines; always move `storage/` outside webroot.

**Further reading (§2):** github.com/opencart/opencart/wiki/Engine · github.com/opencart/opencart/wiki/Events-System · docs.opencart.com/developer-guide/events · source under `upload/system/engine/`

---

# 3. Themes

## 3.1 How OC4 themes work
- **Default theme templates** live in `catalog/view/template/`.
- A **theme is an extension** of type `theme`, living in `extension/<theme>/` with the same subfolder layout: `admin/…` for its settings screen, `catalog/view/template/…` for overrides, `catalog/view/stylesheet/…` for CSS, `catalog/controller/startup/…` for the override event.
- OpenCart ships an **OpenCart Theme Example** package (visible in Extensions → Installer) demonstrating the structure.

## 3.2 The override cascade
OC4 does **not** auto-magically fall back through theme folders the way OC3 did. Instead, a theme extension registers a **`view/*/before` event** that rewrites the template route to point at its own copy when a matching template exists. Canonical pattern (Rupak Nepali / webocreation):
```php
namespace Opencart\Catalog\Controller\Extension\webocreation4\Startup;
class ThemeStandard extends \Opencart\System\Engine\Controller {
    public function index(): void {
        if ($this->config->get('theme_theme_standard_status')) {
            $this->event->register('view/*/before',
                new \Opencart\System\Engine\Action('extension/webocreation4/startup/theme_standard.event'));
            // NOTE: OC4.1 uses '.event'; OC4.0 used '|event'
        }
    }
    public function event(string &$route, array &$args, mixed &$output): void {
        $override = ['common/header'];               // templates this theme overrides
        if (in_array($route, $override)) {
            $route = 'extension/webocreation4/' . $route;   // redirect to our .twig
        }
    }
}
```
Your override template then lives at `extension/webocreation4/catalog/view/template/common/header.twig`.

> **Known friction (community-confirmed):** this override pattern behaves inconsistently across 4.0.2.x → 4.1.0.3; several developers report the header override not taking effect. Test on your exact patch version and confirm the separator (`.` vs `|`).

## 3.3 Customising an existing theme safely
Preferred → least-preferred:
1. **Theme/child extension** overriding only the `.twig` files you change (as above).
2. **Add CSS/JS** via your theme's own stylesheet, injected in an overridden `header.twig` or via a `view/common/header/before` event that appends to `$data['styles']`/`$data['scripts']`.
3. **OCMOD** for surgical template edits when you can't cleanly override a whole file.
4. **Never edit core `catalog/view/template/` files** — upgrades overwrite them.

## 3.4 Creating a new theme from scratch (steps)
1. `extension/<vendor>/` root with **`install.json`** (`name`, `version`, `author`, `link`).
2. **Admin side** (so it appears in Extensions → Themes / Design):
   - `admin/controller/theme/<theme>.php` (namespace `Opencart\Admin\Controller\Extension\<Vendor>\Theme`) with `index()` + `save()`.
   - `admin/model/theme/<theme>.php` (optional).
   - `admin/language/en-gb/theme/<theme>.php`.
   - `admin/view/template/theme/<theme>.twig` (settings form).
3. **Catalog side**:
   - `catalog/controller/startup/<theme>.php` registering the `view/*/before` override event.
   - `catalog/view/template/...` overrides.
   - `catalog/view/stylesheet/stylesheet.css`.
4. Zip **contents** (not the wrapping folder) as `<vendor>.ocmod.zip`; upload via Extensions → Installer; install; enable under Extensions → Themes; assign in Design → Layouts / Theme settings.

## 3.5 Twig deep dive for OC4
- Output: `{{ heading_title }}` (HTML-escaped by default; use `|raw` for trusted HTML).
- Control: `{% if logged %}...{% else %}...{% endif %}`, `{% for product in products %}...{% endfor %}`.
- Composition: OC prefers controller-composed sub-templates passed as pre-rendered HTML (`{{ header }}`, `{{ column_left }}`, `{{ footer }}`) over Twig `{% include %}`.
- Filters commonly used: `|escape`, `|raw`, `|number_format`, `|date`.
- Compilation cache: `system/storage/cache/`. Clear it (Developer Settings → Clear Theme & SASS Cache) whenever a `.twig` change doesn't appear.

## 3.6 Layouts, positions, modules
- **Positions**: `column_left`, `column_right`, `content_top`, `content_bottom`.
- **Layouts** (Design → Layouts) map **routes** to positions and assign modules to positions.
- A module extension renders into a position; layout rows decide which modules appear on which pages.
- Adding a **new position** requires overriding the relevant column/content controller+template (via event or OCMOD) to expose it and adding it to the layout module model — a moderately advanced task.

## 3.7 Front-end assets & bundled libraries
OC4 bundles **Bootstrap 5** and **jQuery 3.6.0** (upgraded, PCI-DSS friendly), plus Font Awesome. OC3 used Bootstrap 3. The admin supports **SASS/SCSS** compilation (Developer Settings). Use Bootstrap 5 `data-bs-toggle` attributes (OC3 used `data-toggle`). For custom pipelines, run your own SASS/PostCSS build and drop compiled CSS into your theme's stylesheet folder.

## 3.8 Responsive / RTL
Bootstrap 5's grid gives responsive behavior out of the box. RTL keys off `{{ direction }}` (`<html dir="{{ direction }}">`) and language-pack `direction` flags; test with an RTL language pack installed.

## 3.9 Common recipes
- **Header/footer**: override `common/header.twig` / `common/footer.twig` via your theme's override event.
- **Product page**: override `product/product.twig`; **product thumbnails are centralized in `product/thumb.twig`** — an OC4 change, so you no longer edit every listing template to restyle a product card.
- **Category page**: override `product/category.twig`; **pagination is centralized in `common/pagination.twig`** (OC4 change).
- **Checkout**: OC4 checkout is heavily AJAX (`data-oc-toggle="ajax"` forms) hitting `checkout/*` controllers.
- **Custom page/route**: add a controller+template+language under your extension and link to `index.php?route=extension/<vendor>/<...>`.

**Further reading (§3):** webocreation.com theme tutorials (install + backend + frontend) · docs.opencart.com Design/Theme Editor · Extensions → Installer "OpenCart Theme Example"

---

# 4. Extensions

## 4.1 Extension types
module, payment, shipping, total (order total), feed, report, theme, language, analytics, currency, captcha, fraud, dashboard. All managed under **Extensions → Extensions** (filter by type).

## 4.2 Anatomy of an OC4 extension
An installed `<name>.ocmod.zip` unpacks into `extension/<name>/`:
```
extension/<vendor>/
├── install.json                       # {name, version, author, link}
├── admin/
│   ├── controller/<type>/<name>.php   # Opencart\Admin\Controller\Extension\<Vendor>\<Type>
│   ├── model/<type>/<name>.php
│   ├── language/en-gb/<type>/<name>.php
│   └── view/template/<type>/<name>.twig
├── catalog/
│   ├── controller/<type>/<name>.php   # Opencart\Catalog\Controller\Extension\<Vendor>\<Type>
│   ├── model/<type>/<name>.php
│   ├── language/en-gb/<type>/<name>.php
│   └── view/template/<type>/<name>.twig
└── ocmod/<name>.ocmod.xml             # optional core patches
```
`install.json` example:
```json
{ "name": "Test Module", "version": "1.0", "author": "Your Name", "link": "https://yourwebsite.com" }
```
(Some docs/tooling also accept `type` and a `license` block.)

## 4.3 `.ocmod.zip` packaging format
- Zip the **contents** (archive root must contain `install.json`, `admin/`, `catalog/`), **not** the wrapping folder.
- Filename must end **`.ocmod.zip`**, be **1–128 characters**, and the package must be **≤ 32 MB**.
- On upload (Extensions → Installer), OC creates `extension/<zipname>/` and records it in `oc_extension_install`; installing it wires it into `oc_extension`.
- Lifecycle: **upload → install (installer) → install (Extensions → Extensions, runs your `install()`) → enable/configure → disable → uninstall (runs `uninstall()`) → delete files.**
- Use a **unique, brand-prefixed name** to avoid clobbering another extension's folder (default OC extensions live in `extension/opencart/`).

## 4.4 OCMOD in OC4 (and how it changed)
OCMOD still exists but is **de-emphasized in favor of events**. It is XML search-and-replace that never edits originals — instead it writes modified copies into `system/storage/modification/`, and the autoloader loads those instead of the core file. XML shape:
```xml
<modification>
  <name>Example OCMOD</name>
  <code>example_ocmod</code>
  <version>1.0</version>
  <author>Your Name</author>
  <file path="admin/controller/common/column_left.php">
    <operation>
      <search><![CDATA[if ($marketplace) {]]></search>
      <add position="before"><![CDATA[ /* injected code */ ]]></add>
    </operation>
  </file>
</modification>
```
- XML instructions are stored in the DB (`oc_modification`); **Extensions → Modifications → Refresh** rebuilds the `system/storage/modification/` cache.
- `position` = `before` | `after` | `replace`.
- **OC4 vs OC3:** OC3 packaged `install.xml` + an `upload/` folder; OC4 puts the XML under the extension's `ocmod/` folder. Some OC4 releases had flaky OCMOD support for `system/library` files — use precise `<search>` anchors and confirm the generated file under `system/storage/modification/`. A missing search string yields `NOT FOUND - OPERATIONS ABORTED!` in the OCMOD log.
- **Rule of thumb:** use **events** for PHP logic; reserve **OCMOD** for template/language tweaks and places events can't reach.

## 4.5 Customising an existing extension without touching its files
1. **Events** targeting its controller/model methods.
2. **OCMOD** patching its templates.
3. **Template overrides** via a theme extension.
4. **A second extension** that registers overriding events or extends via namespace.

## 4.6 Worked examples

### (a) Simple admin + catalog module with a settings form
`admin/controller/module/test_module.php`:
```php
<?php
namespace Opencart\Admin\Controller\Extension\TestModule\Module;
class TestModule extends \Opencart\System\Engine\Controller {
    public function index(): void {
        $this->load->language('extension/test_module/module/test_module');
        $this->document->setTitle($this->language->get('heading_title'));

        $data['breadcrumbs'] = [];
        $data['breadcrumbs'][] = ['text'=>$this->language->get('text_home'),
            'href'=>$this->url->link('common/dashboard','user_token='.$this->session->data['user_token'])];
        $data['breadcrumbs'][] = ['text'=>$this->language->get('heading_title'),
            'href'=>$this->url->link('extension/test_module/module/test_module','user_token='.$this->session->data['user_token'])];

        $data['save'] = $this->url->link('extension/test_module/module/test_module.save','user_token='.$this->session->data['user_token']);
        $data['back'] = $this->url->link('marketplace/extension','user_token='.$this->session->data['user_token'].'&type=module');

        $data['module_test_module_status'] = $this->config->get('module_test_module_status');

        $data['header']      = $this->load->controller('common/header');
        $data['column_left'] = $this->load->controller('common/column_left');
        $data['footer']      = $this->load->controller('common/footer');

        $this->response->setOutput($this->load->view('extension/test_module/module/test_module', $data));
    }

    public function save(): void {
        $this->load->language('extension/test_module/module/test_module');
        $json = [];
        if (!$this->user->hasPermission('modify','extension/test_module/module/test_module')) {
            $json['error'] = $this->language->get('error_permission');
        }
        if (!$json) {
            $this->load->model('setting/setting');
            $this->model_setting_setting->editSetting('module_test_module', $this->request->post);
            $json['success'] = $this->language->get('text_success');
        }
        $this->response->addHeader('Content-Type: application/json');
        $this->response->setOutput(json_encode($json));
    }

    public function install(): void { /* register events / create tables */ }
    public function uninstall(): void { /* remove events / drop tables */ }
}
```
`admin/view/template/module/test_module.twig` (Bootstrap-5 AJAX form):
```twig
{{ header }}{{ column_left }}
<div id="content">
  <form id="form-module" action="{{ save }}" method="post" data-oc-toggle="ajax">
    <div class="form-check form-switch">
      <input type="hidden" name="module_test_module_status" value="0"/>
      <input type="checkbox" name="module_test_module_status" value="1"
             class="form-check-input"{% if module_test_module_status %} checked{% endif %}/>
    </div>
  </form>
</div>
{{ footer }}
```
`admin/language/en-gb/module/test_module.php`:
```php
<?php
$_['heading_title']    = 'Test module';
$_['text_success']     = 'Success: You have modified the module!';
$_['entry_status']     = 'Status';
$_['error_permission'] = 'Warning: You do not have permission to modify this module!';
```
> **OC4 admin form pattern (vs OC3):** `index()` renders; a **separate `save()`** returns **JSON**; the Twig form posts via `data-oc-toggle="ajax"`. This replaced OC3's single-controller postback with `$this->request->post` validation-in-place. Also note **`user_token`** (not OC3's `token`).

### (b) Payment method
Admin controller `extension/<vendor>/admin/controller/payment/<name>.php` (namespace `...Controller\Extension\<Vendor>\Payment`) with `index()/save()`. The catalog **model** exposes `getMethods()`:
```php
namespace Opencart\Catalog\Model\Extension\ExamplePayment\Payment;
class ExamplePayment extends \Opencart\System\Engine\Model {
    public function getMethods(array $address = []): array {
        $this->load->language('extension/example_payment/payment/example_payment');
        // geo-zone check via oc_zone_to_geo_zone, then return the method option array
    }
}
```
The catalog controller renders the payment form/confirm view at checkout.

### (c) Shipping method
Unlike payments, shipping has **no separate catalog controller** — it's driven by the model's `getQuote()`:
```php
namespace Opencart\Catalog\Model\Extension\Opencart\Shipping;
class Flat extends \Opencart\System\Engine\Model {
    public function getQuote(array $address): array {
        $this->load->language('extension/opencart/shipping/flat');
        $query = $this->db->query("SELECT * FROM `".DB_PREFIX."zone_to_geo_zone`
            WHERE geo_zone_id = '".(int)$this->config->get('shipping_flat_geo_zone_id')."'
              AND country_id = '".(int)$address['country_id']."'");
        // build and return quote['flat'] with cost, tax_class_id, etc.
    }
}
```

### (d) Order total
Type `total`; admin controller for settings; the catalog model exposes `getTotal(&$totals, &$taxes, &$total)` to append a line to the order totals during checkout.

### (e) Event-driven extension
See §2.6: `install()` calls `model_setting_event->addEvent()`; listener in `catalog/controller/events.php`:
```php
namespace Opencart\Catalog\Controller\Extension\TestModule;
class Events extends \Opencart\System\Engine\Controller {
    public function onCartAddBefore(&$route, &$data, &$output = null) {
        $this->log->write('onCartAddBefore triggered');
    }
}
```

### (f) Extension that creates DB tables
```php
public function install(): void {
    $this->db->query("CREATE TABLE IF NOT EXISTS `".DB_PREFIX."test_module_data` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `name` VARCHAR(255) NOT NULL,
        `date_added` DATETIME NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT COLLATE=utf8mb4_general_ci;");
}
public function uninstall(): void {
    $this->db->query("DROP TABLE IF EXISTS `".DB_PREFIX."test_module_data`;");
}
```

## 4.7 Admin menu items, dashboard widgets, custom pages, routes
- **Admin menu**: inject into `admin/controller/common/column_left.php`'s `$data['menus']` via OCMOD or a `controller/common/column_left/before` event.
- **Dashboard widget**: extension type `dashboard`.
- **Custom admin page**: a controller under your extension + a menu link with `user_token`.

## 4.8 Startups, tasks & cron
- **Startups** (`oc_startup`): controllers under `.../controller/startup/` run on every request (used to register events programmatically).
- **Cron** (`oc_cron`): extension with a `catalog/controller/cron.php` `index()`; registered in Extensions → Cron Jobs; triggered by an external cron hitting the cron URL (`wget "https://store/index.php?route=..."`). Docs recommend running the CRON task every hour. See docs.opencart.com/developer-guide/cron-jobs and /extension/cron.

## 4.9 Publishing to the marketplace
Provide `install.json` metadata, declare OC version compatibility (OC4 extensions are **not** backward compatible with OC1/2/3 — ship separate releases), follow the coding standards, include docs, use MAJOR.MINOR.FEATURE.PATCH-style versioning, and prefer events/OCMOD over core edits.

**Further reading (§4):** docs.opencart.com/developer-guide/extensions · webkul.com OC4 module/payment guides · webocreation.com OC4 module & OCMOD tutorials · Extensions → Installer example packages (Language/OCMOD/Payment/Theme Example) and `system/storage/marketplace/`

---

# 5. Performance

## 5.1 Built-in cache & drivers
`system/library/cache.php` + drivers in `system/library/cache/`: **file** (default), **mem** (Memcache), **memcached**, **apc/apcu**, **redis**. Configure via constants in **both** `config.php` files, e.g. Redis:
```php
define('CACHE_DRIVER', 'redis');
define('CACHE_HOSTNAME', '127.0.0.1');   // or a unix socket path
define('CACHE_PORT', '6379');
define('CACHE_PREFIX', 'oc_');
define('CACHE_PASSWORD', '');
```
(Memcached uses `MEMCACHE_HOSTNAME`/`MEMCACHE_PORT`/`MEMCACHE_NAMESPACE`.) Redis/Memcached require the corresponding PHP extension (`Class 'Redis' not found` means phpredis is missing → it falls back to file cache). Cache expiry is `$_['cache_expire']` (default **3600s**) in `system/config/default.php`.

## 5.2 Theme/Twig cache
Enable **Theme cache** in Developer Settings; Twig compiles to `system/storage/cache/`. Always **Clear Theme & SASS Cache** after template edits, or your changes won't appear.

## 5.3 Database optimization
- The classic hotspot is **category product counts** (`product_count`): counting products per category on every category render is expensive. Disable it (Admin → System → Settings → store front: "Category Product Count" off) for large catalogs.
- Add indexes on frequently filtered columns; watch heavy queries on product listing, filters, and search.
- Consider a **SEO-URL caching** approach for large `oc_seo_url` tables.

## 5.4 Front-end optimization
- **Image cache**: OC resizes into `image/cache/`; if thumbnails don't regenerate, clear `image/cache/` and check `image/` permissions. Serve WebP where possible.
- Minify/concatenate CSS/JS; use `srcset` for responsive images; lazy-load below-the-fold images.
- Enable **Output Compression Level** (gzip) in System → Settings → Server (value 0–9; ~5 is a common sweet spot); prefer brotli at the server if available.
- HTTP/2, a CDN for static assets, and long `Cache-Control`/`Expires` headers on `js|css|images` via `.htaccess`/Nginx.

## 5.5 PHP & server
- **OPcache** on with generous `memory_consumption` and `max_accelerated_files`; PHP 8.1+ is materially faster than 7.x. JIT can help CPU-bound work but test — it rarely moves the needle for I/O-bound storefronts.
- **Apache**: rename `.htaccess.txt` → `.htaccess` for SEO-URL rewrites; enable `mod_deflate`, `mod_expires`.
- **Nginx**: use a `try_files` rewrite to `index.php?...` for SEO URLs; add FastCGI cache carefully (bypass for cart/checkout/logged-in sessions).

## 5.6 MySQL tuning
Tune `innodb_buffer_pool_size` (256M+ on mid stores), `max_connections`, `tmp_table_size`/`max_heap_table_size`. **MySQL's query cache is removed in MySQL 8.0** — rely on the InnoDB buffer pool + application (Redis) cache instead.

## 5.7 Full-page caching pitfalls
Full-page cache must **exclude** cart, checkout, account, and any session-dependent fragment, or customers will see each other's carts. Prefer fragment/object caching (Redis) over naive FPC for OpenCart. Commercial FPC extensions (e.g. "Lightning") explicitly step aside for dynamic pages.

## 5.8 Sessions & large catalogs
- Session storage: file (default), db, or redis — **Redis sessions scale best** under load.
- 100k+ products: disable category counts, ensure indexes, use Redis cache+sessions, offload images to CDN, and profile the specific slow routes.

## 5.9 Profiling tools & anti-patterns
Xdebug (dev profiling), Blackfire, New Relic (APM), MySQL slow-query log, and OpenCart's error log + `$this->log->write()`. A common **anti-pattern in third-party extensions**: registering heavy listeners on `view/*/before` (runs on every view render) or issuing per-row queries in loops.

**Further reading (§5):** webocreation.com "10 ways to speed up OpenCart" · `system/library/cache/` drivers · hosting.xyz OpenCart Redis/Memcached guides

---

# 6. Contributing to OpenCart Core

## 6.1 Repo layout & branches
Repo: **github.com/opencart/opencart**. Root contains `.github/`, `docker/`, `docs/`, `tools/`, `upload/` (the actual product), plus root files: `.editorconfig`, `.gitignore`, `.php-cs-fixer.php`, `CHANGELOG.md`, `CONTRIBUTING.md`, `INSTALL.md`, `LICENSE.md`, `Makefile`, `README.md`, `UPGRADE.md`, `apigen.neon`, `buildspec.yml`, `composer.json`, `composer.lock`, `crowdin.yml`, `docker-compose.yml`, `phpstan.neon`.

- **`master`** = the active development branch. Per the README: *"The master branch will always contain an '\_rc' postfix of the next intended version. The next '\_rc' version may change at any time."* Current 4.x development flows through `master` (PR titles prefixed `[4.x.x.x]`).
- **`3.0.x.x`** and **`3.0.x.x_Maintenance`** = legacy/maintenance line (still recommended by many for production).
- **`opencart-l10n`** = localization branch fed by Crowdin.
- `4.1.x.x` / `4.x.x.x` appear as **PR/issue labels** (e.g. "target: master — Issues and PRs targeting the master branch") and title prefixes rather than a separate long-lived branch. *(Note: whether a standalone long-lived `4.1.x.x` git branch exists could not be definitively confirmed — 4.x work currently flows through `master`.)*

**→ Target your PRs at `master`.**

## 6.2 Coding standards (enforced)
From docs.opencart.com/developer-guide/coding-standard and the GitHub wiki:
- Files: `.php` for code, `.twig` for templates; LF line endings (Git-managed). PHP files after 2.0 have **no closing `?>` tag**.
- **Indentation: TAB in PHP and JavaScript; 2 spaces for HTML in `.twig`.**
- Spacing: `if () {`, `} else {`, `(int)$var` (**no space after cast**), `$var = 1;` (spaces around `=`).
- **1TBS braces** (opening brace on same line, space before it).
- **File names**: lowercase + underscores. **Class & method names**: camelCase (`class ModelExampleExample`, `public function addExample()`). Method scope always declared (`public function`).
- **Helper functions & variables**: lowercase + underscores (`$new_var`). **User constants**: UPPERCASE. `true/false/null`: lowercase.
- HTML/CSS class & id: hyphenated (`my-class`), not underscored.
- OC4 adds **type hints and PHPDoc** throughout (return types like `: void`, typed params).

## 6.3 CI / how PRs are gated
There is **no PHPUnit test suite in core** — quality is enforced entirely by static analysis and linting. The CI workflow is **`.github/workflows/Lint.yml`** (the only status badge on the README). Per the README: *"Your code must follow the OpenCart coding standards. Our automated scanners (syntax lint, PHPStan, php-cs-fixer) must pass before a PR can be merged."* Run the same checks locally before opening a PR:
```bash
# 1) PHP syntax lint (skips bundled vendor code)
find upload -type f -name "*.php" ! -path 'upload/system/storage/vendor/*' -exec php -l -n {} +

# 2) PHPStan static analysis (level 6, config phpstan.neon)
php tools/phpstan.phar analyze --no-progress

# 3) Code style
php tools/php-cs-fixer.phar fix --dry-run --diff --ansi
# to auto-apply fixes, run again WITHOUT --dry-run and commit the result
```
`phpstan.neon` pins **`level: 6`**, analyzes `./upload/`, excludes `tools/phpstan/`, `system/storage/vendor/`, and `system/storage/cache/`, and registers a custom `RegistryPropertyReflectionExtension` so PHPStan understands the registry magic properties. Config files at repo root: `phpstan.neon`, `.php-cs-fixer.php`; the phars live in `tools/`. *(The `.github/copilot-instructions.md` also summarizes the MVC-A conventions for contributors.)*

## 6.4 Dev environment from the clone
The clone gives you the **repo tree** (with `upload/`, `tools/`, `docker/`), unlike the distribution zip which ships only the packaged store. CONTRIBUTING.md recommends **Docker via the Makefile** (`make init/build/up/php`), needs **PHP 8.0+** with `curl`, `gd`, `zip`, and `composer install --no-interaction` (installs into `upload/system/storage/vendor/`). Point your webroot at `upload/`.

## 6.5 Git workflow (fork & pull)
1. Fork on GitHub → clone your fork locally.
2. **Create a branch from `master`** (e.g. `feature/cart-api`, `fix/seo-url-regression`).
3. Make focused changes; **avoid formatting-only churn**; always test on a real install (local or demo).
4. Imperative commit subjects; be descriptive; reference issues with `Fixes #1234`.
5. **Rebase onto latest `master`** before opening/updating the PR to keep history clean.
6. Push; open a PR **into `opencart:master`**; fill the template (motivation, testing notes, screenshots for UI). The comparison should read `opencart:master ... yourusername:your-branch`.
7. **Don't add unrelated commits** to the PR branch afterward — extra commits become part of the PR and can force a decline.

## 6.6 Reporting bugs
Search the forum, check open/closed issues, confirm it's core (not hosting/extension), then file on GitHub with **exact reproduction steps**. **Security issues** must be reported **privately** (PM an OpenCart moderator/administrator on the forum) — never posted publicly, and never as unproven concepts.

## 6.7 Tracing a bug from URL to code
`index.php?route=product/category` → `catalog/controller/product/category.php::index()` → the models it loads (`catalog/model/catalog/category.php`, `product.php`) → the `.twig` it renders. Use the route to jump straight to the responsible files; check `system/storage/logs/error.log` and enable Display Errors.

## 6.8 Translations
Do **not** PR `language/*` edits — they are closed in favor of the **Crowdin** workflow (`crowdin.yml`, `opencart-l10n` branch).

## 6.9 Releases & versioning
**MAJOR.MINOR.FEATURE.PATCH** (e.g. 4.1.0.3). A MAJOR is very rare (effectively a rewrite). PATCH = safe fix. Per the README: *"OpenCart will announce to developers 1 week prior to public release of FEATURE versions, this is to allow for testing of their own modules for compatibility."* Bigger releases get an extended period with a release candidate (RC). The schema PDF is at docs.opencart.com/developer-guide/database-schema; upgrade scripts live under `install/`.

## 6.10 Maintainers & community
- **Daniel Kerr (@danielkerr)** — creator/owner (OpenCart Limited); the primary merger.
- Active contributors seen in recent releases: **@TheCartpenter** (PHPDoc/model cleanup), **@condor2** (created the CI configs), **@AJenbo** (CI/PHP-version maintenance), **@ADDCreative** (security fixes), **@opencartbot**, **@mhcwebdesign**, **@eka7a**.
- Community: the **OpenCart forum** (forum.opencart.com) and GitHub Issues/Discussions. **Good first contributions:** PHPDoc/comment fixes, small bug fixes, documentation, and extension-scoped improvements (core is kept "intentionally slim" — new features are often steered toward extensions under `upload/extension/` rather than `system/` core edits).

**Further reading (§6):** github.com/opencart/opencart/blob/master/CONTRIBUTING.md · /README.md · /phpstan.neon · /wiki/Coding-standards · /wiki/Creating-a-pull-request · docs.opencart.com/developer-guide/coding-standard

---

# 7. Practical Learning Path, Glossary & Troubleshooting

## 7.1 Prerequisites
PHP 8 OOP (namespaces, type hints, magic `__get`/`__call`), Composer basics, MySQL, HTML/CSS/JS, Bootstrap 5, Twig, and Git.

## 7.2 Milestone curriculum for a fresher
- **Week 1 — Setup & orientation.** Install OC4.1 locally (Docker or XAMPP/Laragon). Explore the whole admin. Study the directory tree. *Exercise:* move `storage/` outside webroot; toggle Developer Settings; find and read `error.log`.
- **Week 2 — Request lifecycle & engine.** Read `index.php`, `system/startup.php`, `system/framework.php`, and `system/engine/*`. *Exercise:* add a `$this->log->write()` in a local controller and trace it end-to-end via a route.
- **Week 3 — MVC-L + Loader.** Build a "Hello World" storefront controller+template+language. *Exercise:* load a model and render its data to a Twig page.
- **Week 4 — Events & Proxy.** Register a `catalog/controller/checkout/cart.add/after` listener that logs. *Exercise:* deliberately break the separator (`.` vs `|`) to see the 4.0-vs-4.1 issue first-hand.
- **Week 5 — Extensions.** Build module (a) with a settings form (`index()`+`save()` JSON), then (f) DB tables in `install()/uninstall()`. Package as `.ocmod.zip` and install.
- **Week 6 — Payment/shipping/total.** Implement one of each using the bundled example packages (`extension/opencart/…`, `system/storage/marketplace/`) as templates.
- **Week 7 — Themes.** Create a theme extension overriding `common/header.twig` via a `view/*/before` event; add SASS-built CSS.
- **Week 8 — Performance.** Enable Redis cache + sessions; disable category counts; tune OPcache; measure before/after with PageSpeed and the slow-query log.
- **Week 9 — Contributing.** Fork, set up the Docker dev env, run `php -l`/PHPStan/php-cs-fixer, fix a "good first issue" (docblock/typo/small bug), open a PR to `master`.

## 7.3 Recommended resources
- **Official:** docs.opencart.com (Developer Guide: Coding Standard, Database Schema, Extensions, Events, Startups, Tasks, Cron Jobs). `docs.opencart.com/llms.txt` indexes everything; append `.md` to any page for Markdown.
- **GitHub:** github.com/opencart/opencart (source, wiki, CONTRIBUTING, issues, discussions).
- **Community:** forum.opencart.com.
- **Tutorials/blogs:** webocreation.com (Rupak Nepali — OC4 theme/module/OCMOD/events), webkul.com blog (OC4 module/payment), opencartbot.com (release notes, events, performance).
- **Books:** Rupak Nepali, *OpenCart 4: Dev Guide for Themes & Extensions* (Amazon).
- **Reference repo:** github.com/IP-CAM/OC-4-Extension-Development-Guide.

## 7.4 Glossary
- **MVC-L** — Model/View/Controller/Language.
- **Registry** — service container holding all core objects.
- **Loader** — `$this->load->…` component loader.
- **Action** — route→controller+method wrapper.
- **Factory** — builds controller/model objects for the Loader.
- **Proxy** — model wrapper enabling method-level events.
- **Event** — publisher/subscriber hook (`namespace/action/stage`).
- **OCMOD** — XML virtual-file modification system.
- **`.ocmod.zip`** — the OC4 extension package format.
- **`install.json`** — extension metadata manifest.
- **`user_token`** — admin session/CSRF token (OC3's `token`).
- **`DB_PREFIX`** — table-name prefix (`oc_`).
- **Layout/Position** — page template + module slots (`column_left`, `column_right`, `content_top`, `content_bottom`).
- **Startup** — controller run on every request.

## 7.5 Troubleshooting guide
| Symptom | Likely cause / fix |
|---|---|
| **Blank white page (WSOD)** | PHP fatal; enable Display Errors + read `system/storage/logs/error.log`. Often a namespace/class-name mismatch or PHP-version issue. |
| **Permission errors** | `storage/` (cache/logs/session) not writable; fix ownership/permissions. |
| **Changes not showing** | Clear cache: Developer Settings → Clear Theme & SASS Cache; delete `system/storage/cache/*`. |
| **"Extension not showing"** | Not installed in Extensions → Extensions after upload; wrong `install.json`; folder/namespace mismatch; config status key not set. |
| **Modification not applied** | Extensions → Modifications → **Refresh**; check OCMOD log for `NOT FOUND - OPERATIONS ABORTED!` (search anchor wrong). |
| **SEO URL 404s** | `.htaccess` missing/rewrite off; Nginx `try_files` missing; SEO URL disabled in settings. |
| **Image cache not regenerating** | Clear `image/cache/`; check `image/` permissions. |
| **Event never fires** | Wrong separator (`.` in 4.1 vs `|`/`/` in older); wrong trigger string; extension disabled; event not in `oc_event`; referring to `index` explicitly. |
| **`Class 'Redis' not found`** | phpredis extension not installed; falls back to file cache. |
| **Could not load DB adaptor pdo** | Install with `mysqli`, then switch to `mpdo` in both config files. |
| **`install.json could not be found`** | You zipped the wrapping folder; zip the *contents* so `install.json` is at the archive root. |

## 7.6 Debugging techniques
- `$this->log->write($x)` → `error.log`; view under System → Maintenance → Error Logs.
- Enable Display Errors during dev only.
- Trace from `route=` to files; inspect `oc_event`, `oc_modification`, `oc_extension`, `oc_setting` in the DB.
- Use Xdebug step-debugging into `system/framework.php` to watch the object graph assemble.

## 7.7 Caveats & uncertainty
- Official developer docs are **thin/uneven** in places; the source code + wiki + community blogs (webocreation, webkul, opencartbot) fill gaps — **cross-check against your exact patch version**.
- The **theme override event** pattern behaves inconsistently across 4.0.2.x→4.1.0.3 per multiple community reports; verify on your version.
- OC4 is **not backward compatible** with OC1/2/3 extensions/themes — ship OC4-specific releases.
- The **4.0→4.1 event-separator change** (`|`/`/` → `.`) and the **`oc_product_code` table move** break some 4.0 extensions.
- Whether a standalone long-lived `4.1.x.x` git branch exists is unconfirmed; current 4.x work flows through `master` with `[4.x.x.x]`/`target: master` labels — confirm before branching.
- Core has **no PHPUnit suite**; if you want automated tests for your own OpenCart work, the third-party `beyondit/opencart-test-suite` (PHPUnit-based) is the common choice, but it is **not** part of core.

**Further reading (§7):** docs.opencart.com/llms.txt · webocreation.com/opencart-tutorial · forum.opencart.com · github.com/opencart/opencart/wiki

---

## Recommendations (staged, decision-ready)

**Stage 0 — Environment (do first).** Install OC4.1.0.4 on Docker (contributor path) or Laragon/XAMPP. Turn on Error Logging + Display Errors, and bookmark Developer Settings → Clear Cache. *Threshold to proceed:* you can install, break, and reinstall the store from scratch in under 10 minutes.

**Stage 1 — Read the engine before writing code.** Spend real time in `system/engine/` and `system/framework.php`. Do not skip this — every later task (themes, extensions, contributing) depends on understanding Registry/Loader/Action/Event/Proxy. *Threshold:* you can explain, from memory, what happens between a URL and a rendered Twig page.

**Stage 2 — Build the six worked extensions (§4.6).** In order: module-with-settings → DB-tables module → event listener → payment → shipping → total. Package each as `.ocmod.zip` and install through the admin. *Threshold:* your module's `save()` returns JSON, persists to `oc_setting`, and its `uninstall()` cleans up.

**Stage 3 — Theme work.** Create a theme extension that overrides `common/header.twig` via a `view/*/before` event. Confirm the `.` separator on your version. *Threshold:* your header renders instead of the default and survives a cache clear.

**Stage 4 — Performance.** On a seeded catalog, enable theme cache, switch to Redis cache+sessions, disable category product counts, and enable OPcache. Measure TTFB before/after. *Threshold:* a measurable TTFB drop and green-ish PageSpeed on category/product pages.

**Stage 5 — Contribute.** Fork, run the three CI checks locally until clean, and submit a small PR (docblock/typo/bug) against `master`. *Threshold:* CI (`Lint.yml`) passes and your PR follows the coding standard and commit conventions.

**Benchmarks that change the plan:** if you must ship to production *now* and need a mature extension ecosystem, consider the 3.0.x line instead of 4.x (widely advised by the community through 2024–2025) — but for *learning the current platform and contributing*, 4.1.x is the correct target. If your store exceeds ~50k products or high concurrency, escalate straight to Redis sessions + object cache and CDN before adding features.

## Caveats (summary)
This document reflects OpenCart as of the 4.1.x line (through 4.1.0.4, Aug 2026) and the current `master` development branch. OpenCart's official developer documentation is incomplete in several areas, so some architectural details are drawn from source code, the GitHub wiki, and reputable community tutorials rather than first-party prose; where the community disagrees or behavior is version-sensitive (notably the theme-override event and the 4.0→4.1 event separator), that is flagged inline. Always validate code against your exact patch version, and never run `master` or an unreleased build on a live store.
Cookie settings
We use cookies to deliver and improve our services, analyze site usage, and if you agree, to customize or personalize your experience and market our services to you. You can read our Cookie Policy here.
