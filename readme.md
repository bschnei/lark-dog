This project gave me a fun reason to keep track of how the open source [PhotoPrism](https://github.com/photoprism/photoprism) project evolved. In July 2024, I switched from PhotoPrism to [HomeGallery](https://home-gallery.org/) as a frontend for a simple read-only photo gallery which seems to be a better solution for that specific use case. As a result, this repo is not maintained, and I no longer use the code to run or configure any services.

I originally became interested in using PhotoPrism as a potential replacement for the self-hosted, closed source [Photos](https://www.synology.com/en-us/dsm/feature/photos) application that I had been using for a few years. IMHO, Photos was the closest self-hosted alternative (feature-wise) to something like Google Photos in 2022. Since then, [Ente](https://ente.io/) has shown up as a promising self-hosted, open source Google Photos alternative.

At the time I set lark.dog up, [multi-user support](https://github.com/photoprism/photoprism/issues/98) and associated role-based permissions, were the missing features preventing me from adopting it for personal use. So instead I got the idea to see how it does as a public-facing website (i.e. no login required).

TL;DR: I was mostly happy with it even though the lead developer didn't seem to be targeting this specific use case.

PhotoPrism did not have great support for enabling/disabling certain features piecemeal which made it a bit awkward to use as a public website. Specifically, I would have liked the ability to have most of the site be read-only, except to an admin. Using the built-in "read only" mode seemed like it would have been a good solution but doing so disabled the auto-import function and the built-in WebDAV service even though the service required a login to use. So I changed one line of code to enable the WebDAV service and changed settings to hide features that would give a user the ability to modify data.

In other words, it was modified so the only ability to write data to the server was via the authenticated WebDAV service.

While it "worked", this use case didn't seem aligned with the project's longer-term goals. At some point the project also took some pretty basic features that were free in earlier releases and put them behind a donationwall in subsequent releases. The configuration also can be confusing/subject to breaking changes. But it performs well on the cheapest virtual hardware and has a *beautiful* and clean UI.

The terraform code helps set up virtual resources on Google Cloud Platform and configuring DNS records on Namecheap.

A small virtual machine only runs docker. The frontend, backend, and [gateway](https://github.com/linuxserver/docker-swag) are all services specified in the docker-compose file.
