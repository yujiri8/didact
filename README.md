# Didact, the user-respecting anti-CMS!

Didact's philosophy is explained [here](https://yujiri.xyz/didact).

## Setup

1. Log into your server.

2. Clone the Didact repository with [Git](https://git-scm.com) (it will never be packaged in a binary distribution): `git clone https://github.com/yujiri8/didact`. Alternately, download it locally and copy it to your server.

3. Install the dependencies. They should be in the repository for any Unix operating system, but the exact names of packages might vary so I can't give exact install instructions. The dependencies are:

	* The [Crystal](https://crystal-lang.org) compiler, and its package manager, [Shards](https://github.com/crystal-lang/shards), for Didact itself
	* [npm](https://npm.org), the Node package manager. Used to install Javascript modules for the frontend.
	* [Nginx](https://nginx.org), the outward-facing web server
	* [SQLite](https://sqlite.org), the database engine
	* [OpenSMTPD](https://opensmtpd.org), the mail transfer agent, for email notifications (see also [Email setup](#email-setup))
	* [entr](https://entrproject.org), a command-line tool used by Didact's `monitor.sh` script to automatically update files
	* `find`, another command-line tool used by `monitor.sh`. May be preinstalled, but if not, the package for it is probably called "findutils".

	Nginx and OpenSMTPD need to be set to start at boot time with your system's service manager (and then started (but don't start Nginx until after step 7)).

4. Copy the example content from `example/` to `content/`. (This should be done before the next step because at least a `global.css` is required to be in the `content/` folder.)

5. Compile Didact:

	1. Be in the repository root.
	2. Run `shards --production` to install Crystal dependencies.
	3. Run `npm install` to install Javascript dependencies.
	4. Run `./build.sh`. This may take a minute. **Note that you need to re-run this script after changing any template files.**

6. Copy `didact.yml.example` to `didact.yml` and fill out the necessary settings for your site. The example file has comments explaining the settings.

7. Install configurations for dependencies by running `src/scripts/install.cr`.

8. Run `src/scripts/createdb.cr` to create the database.

9. Your content goes in `content/` (see [Adding content](#adding-content)). The folder is not tracked by git, and the recommended way to use Didact is to store your content in its own repository that you put there.

	Nginx will need read access to `html/`. If you don't want to give it read access to your home folder, you can achieve this by making a symlink to `html/` in a place that Nginx can read.

The test script `tests/test.sh` performs the required steps on a new FreeBSD server and may be a useful guide if the above instructions are unclear.

## Adding content

Content goes in `content/`. The template script, `didact-template`, will read this folder and populate `html/` with the actual files to be served to browsers. Any content file that doesn't end in `.md` or `.html` (images, downloads, etc), is assumed to be a static file, and will be hard-linked directly to the deploy folder. Files that do end in `.md` or `.html` are your main text context.

Text content files are not copied verbatim. The template script reads the `content-templates` folder and fills out the default template (or one you specify) using the content file, so you don't have to write boilerplate HTML. A content file consists of a few settings at the top, a blank line, and then the content of the page. The settings understood by the default template are:

* `TITLE ...` - (required) [SEO](https://moz.com/beginners-guide-to-seo) title to be displayed as the title of the browser window and in search results.

* `NAV ...` - The title segment to display in the navbar, after category. Defaults to the value of `TITLE` (except for index pages).

* `DESC ...` - The description to display in contexts like search results and social media link previews.

* `TEMPLATE ...` - says which page template to use (don't include the `.ecr` suffix of the template filename). Defaults to `default`, so `default.ecr` will be used.

* `JS ...` - names a Javascript file to include. `/global.js` is included by default, which contains all of the Javascript for Didact (it will be generated by `build.sh` and written to the deploy folder).

* `CSS ...` - names a CSS stylesheet to include. `/global.css` is included by default, which should be the name of your main stylesheet.

* `NOINDEX` - include an HTML meta tag that tells search engines not to show the page in search results.

* `ONLOAD ...` - specifies a line of Javascript to be executed when the page loads.

* `ONRESIZE ...` - specifies a line of Javascript to be executed when the window is resized.

Content files that end in `.md` have their content (not the template settings at the top) processed using the [Sanemark](https://yujiri.xyz/sanemark) processor, which allows you to write them in Sanemark, a lightweight format for text content that's more convenient than raw HTML. Files that end in `.html` are not processed as Sanemark.

Content can be organized hierarchically via subfolders in the content folder. Each directory should have an `index.md` or `index.html` that acts as the index page for that category or section of your site.

Content templates are written in [ECR](https://crystal-lang.org/api/ECR.html) (Embedded CRystal), so learning some Crystal will help if you wish to customize them.

The included `monitor.sh` is meant to run in the background. It monitors `content/` for changes and automatically re-runs `didact-template` as necessary. However, it can only detect changes to existing files, not new files, renames, or removals. So if you change those things, you'll need to restart `monitor.sh`.

Due to a technical limitation, the CSS needs to be duplicated between `content/global.css` and `js/css.js`. There is a pre-build script that handles this, called by `build.sh`, so you don't need to worry about it unless you change `global.css`.

## Email setup

By default, most mail servers will either reject your mail or show it with some sort of "couldn't verify sender" warning (very likely to be sent to spam). You need to prove to the server that your email is coming from the address it says it is. The simplest way is to [set up an SPF DNS record for your domain](https://www.dmarcanalyzer.com/spf/how-to-create-an-spf-txt-record/).

Note that the "Be notified when new articles are posted" setting for your users doesn't do anything on its own; you can email all subscribers with `crystal src/scripts/email-subscribers.cr` (it'll let you enter the message). This is done because Didact doesn't control your publishing process so it doesn't know when a new article is posted, and because it's more flexible to make these emails manual (for example, you can post an unlisted page and not email people; you can email them about updates other than new articles; you can email them when you make major changes to an existing post but without technically posting it a new article, etc).

## Advanced instructions

To rebuild faster after a change, you can run individual commands out of `build.sh` to rebuild only the components that need it instead of the whole thing. The server needs a rebuild after changing email templates, the templater needs a rebuild after changing content templates, and the Javascript needs a rebuild after changing `global.css`. (It also helps to build Crystal stuff without the `--release` flag if it's a test build. That flag turns on optimizations that make it take significantly longer to build.)

Run `crystal docs` from the repository root to fill the `docs` folder with HTML documentation on the Crystal code.
