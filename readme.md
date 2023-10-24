This is a hobby project that allows me to keep track of how the open source [PhotoPrism](https://github.com/photoprism/photoprism) project evolves.

I originally became interested in using it as a potential replacement for the self-hosted, closed source [Photos](https://www.synology.com/en-us/dsm/feature/photos) application that I had been using for a few years. IMHO, Photos was the closest self-hosted alternative (feature-wise) to something like Google Photos (in 2022). However, self-hosted solutions demand a lot of time to make them stable and reachable (securely) outside of your own home.

There are other open source photo management applications besides PhotoPrism. I poked at some of them but found them further behind feature- and looks-wise. It's a space I feel is worth watching because the gap betwen open and closed source solutions is wider than in most categories.

At the time I set lark.dog up, [multi-user support](https://github.com/photoprism/photoprism/issues/98) and associated role-based permissions, were the missing features preventing me from adopting it for personal use. So instead I got the idea to see how it does as a public-facing website (i.e. no login required).

TL;DR: I've been mostly happy with it even though the lead developer doesn't seem to be targeting this specific use case.

PhotoPrism does not currently have great support for enabling/disabling certain features piecemeal which makes it a bit awkward to use as a public website. Specifically, I would like the ability to have most of the site be read-only, except to an admin. Using the built-in "read only" mode seemed like it would be a good solution but doing so disables the auto-import function and the built-in WebDAV service even though the service requires a login to use. So I change one line of code to enable the WebDAV service and change settings to hide features that would give a user the ability to modify data.

In other words, it's been modified so the only ability to write data to the server is via the authenticated WebDAV service.

While it "works", this use case doesn't seem aligned with the project's longer-term goals. At some point the project also took some pretty basic features that were free in earlier releases and put them behind a donationwall in subsequent releases. The configuration also can be confusing. But it performs well on the cheapest virtual hardware and has a *beautiful* and clean UI.

The terraform code helps set up virtual resources on Google Cloud Platform and configuring DNS records on Namecheap.

A small virtual machine only runs docker. The frontend, backend, and [gateway](https://github.com/linuxserver/docker-swag) are all services specified in the docker-compose file.
