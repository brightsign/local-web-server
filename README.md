#README - local-web-server

##Overview
This repository is a collection of files useful for devloping a custom local web server on a Brightsign player.  Some of these functions might also be useful in HTML zones in actual presentations.

Summary of files:

* default.html - the current default single page user varialbe web page
* example.html - the default page broken out into seperate html, js and css files
* example-w-udp.html - an example that has buttons on the page to trigger sending UDP events supported by the player's presentation
* vartest.html - and example that sets text on the page based on the value of user variables 
* js - a folder with javascript files
* css - a folder with CSS files
* images - a folder with images
* brs - a folder with BrightScript code that could be of use
 
NOTE:  to get UDP support in the current test version of BrigthAuthor (2.7.0.13) you need to specify the custom autorun autorun-udp-local.brs found in the brs folder.

The functionality exposed in the example html files has been at least partially tested.  Some extra javascript funtionality not shown in those examples is very much a work in progress.

##Javascript

We use jQuery and currently for some functionality we use the jquery.xml2json.js plugin.  Other js files are:

* bsp.js - base code needed by all pages
* sfn.js - code useful to interact with presentations published with Simple File Networking.  Work in progress.
* mrss.js - code useful to read DYnamic Playlists and Live Text from BrightSignNetwork (and potentially other MRSS feeds).  Very much a work in progress.


