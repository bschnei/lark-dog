This is a hobby project that allows me to keep track of how the open source [PhotoPrism](https://github.com/photoprism/photoprism) project evolves.

I originally became interested in using it as a potential replacement for the closed source [Photos](https://www.synology.com/en-us/dsm/feature/photos) web application that I had been using for a few years. Photos was a huge improvement from Synology's older [PhotoStation](https://www.synology.com/en-us/dsm/feature/photo_station) application, despite having some quirks. In my opinion, it is the closest alternative (feature-wise) to something like Google Photos that exists in September 2022. You just have to be pretty dedicated to sytem and network admin to make it reachable (securely) outside of your own home.

There are other open source photo management web application besides PhotoPrism. I poked at some of them but found them further behind feature- and looks-wise.

[Multi-user support](https://github.com/photoprism/photoprism/issues/98) has been the missing feature preventing me from adopting it for personal use. So instead I've been seeing how it does as a public-facing website (i.e. no login required).

TL;DR: I've been quite happy with it even though the developers don't seem to be targeting that use case.

PhotoPrism does not currently have great support for enabling/disabling certain features piecemeal which makes it a bit awkward to use as a public website. Specifically, I would like the ability to have most of the site be read-only, except to an admin. Using the built-in "read only" mode seemed like it would be a good solution but doing so disables the auto-import function and the built-in WebDAV service even though the service requires a login to use. So I change one line of code to enable the WebDAV service and change settings to hide features that would give a user the ability to modify data.

In other words, it's been modified so the only ability to write data to the server is via the authenticated WebDAV service.

While it "works", this use case doesn't seem aligned with the project's longer-term business goals. They also took some pretty basic features that were free in previous releases and put them behind a donationwall.

The terraform code in this repo helps set up virtual resources on Google Cloud Platform. It also handles configuring DNS records on Namecheap.

A small virtual machine only runs docker. The frontend, backend, and [gateway](https://github.com/linuxserver/docker-swag) are all services specified in the docker-compose file.
