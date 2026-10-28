![DIƒƒER logo](./content/logo.png)

Self-hosted diff tool that compares two versions of text in the browser. A simple alternative to diffchecker.com.

This is a simplified, static-only fork of [EmergingTravel/differ](https://github.com/EmergingTravel/differ). It has no server-side code, database or build step. Apache serves it as plain files.

> **Need shareable links?** This fork has removed the save/share feature. If you want to save diffs and share them by link, use the original project: [EmergingTravel/differ](https://github.com/EmergingTravel/differ). It uses Node.js, PostgreSQL and Docker.

## Features

- Compare two versions of text and highlight the differences side by side.
- Go back and edit the texts, then compare again.
- Download the result as a unified `.patch` file.
- Everything runs in the browser. Your text is never sent to the server.

## Installation

Requirements: Apache httpd 2.4 on Linux (tested on Ubuntu). Nothing else is needed: no Node.js, no database, no internet access.

1. Copy the project folder into Apache's web directory:

   ```sh
   sudo cp -r differ /var/www/html/differ
   ```

2. Run the check script:

   ```sh
   sudo bash /var/www/html/differ/check.sh
   ```

   It checks that Apache is installed and running, the required modules are enabled, all files are present and readable by `www-data`, and the `.htaccess` rules are working. If something is wrong, it prints the command or config line that fixes it. It never changes anything itself.

3. Open `http://<your-server>/differ/`.

### Allowing `.htaccess`

The included [`.htaccess`](.htaccess) turns off directory listings and blocks web access to everything the browser doesn't need: dot-files and folders such as `.git` and `.vscode`, the `content/` folder (README images), and `README.md`, `LICENSE` and `check.sh`. Only `index.html` and `client/` are served.

On Ubuntu, Apache ignores `.htaccess` files by default. If `check.sh` reports that the rules aren't applied, add this to your site config, for example `/etc/apache2/sites-available/000-default.conf`, and reload Apache:

```apache
<Directory /var/www/html/differ>
    AllowOverride All
</Directory>
```

```sh
sudo systemctl reload apache2
```

If you would rather not copy `.git` to the server at all, copy only what's needed:

```sh
sudo rsync -a --exclude .git --exclude .vscode differ/ /var/www/html/differ/
```

## Usage

![Usage example](./content/usage.gif)

1. Open the page.
2. Enter the text in the left and right text areas.
3. Optionally enter a name for the diff, such as a ticket number.
4. Click the `Compare` button. The differences are highlighted.
5. Click `Edit` to go back and change the texts.
6. Click `Download` to save the diff as a `.patch` file, named after the diff name.

## Project layout

```
index.html          the page
client/css/         styles (vendor/ holds third-party CSS)
client/js/          app code (vendor/ holds third-party JS)
client/img/         favicon
.htaccess           Apache rules: directory index, access blocking
check.sh            deployment check
content/            README images (not served)
```

This service is built on top of a bunch of great open-source libraries:

- [jsdiff](https://github.com/kpdecker/jsdiff)
- [diff2html](https://github.com/rtfpessoa/diff2html)
- [micromodal](https://github.com/ghosh/Micromodal)
- [pure-css](https://github.com/pure-css/pure)

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.

Original work copyright (c) 2024 ETG ([EmergingTravel/differ](https://github.com/EmergingTravel/differ)).
Modifications in this fork copyright (c) 2026 J.T.Stokkeland.
