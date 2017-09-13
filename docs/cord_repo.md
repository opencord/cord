# Getting the Source Code

## Install repo
Repo is a tool from Google that help us managing the code base.

```
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/repo && \
sudo chmod a+x repo && \
sudo cp repo /usr/bin
```

## Download CORD Repositories

<pre><code>mkdir ~/cord && \
cd ~/cord && \
repo init -u https://gerrit.opencord.org/manifest -b {{ book.branch }} && \
repo sync</code></pre>

>NOTE: `master` is used as an example. You can substitute your favorite
>branch for `master`, for example, `cord-4.0` or `cord-3.0`. You can
>also use  flavor-specific manifests such as `mcord` or `ecord`. The
>flavor you use here is not correlated to the profile you will choose
>to run later, but it is suggested that you use the corresponding
>manifest for the deployment you want. For example, if you use the
>`ecord` manifest then it would be typical to deploy the
>`ecord.yml` service profile. 

When this is complete, a listing (`ls`) inside this directory should yield output similar to:

```
ls -F
build/         incubator/     onos-apps/     orchestration/ test/
```

##  Contribute Code to CORD

We use [Gerrit](https://gerrit.opencord.org) to manage the code base.
For more information about how to commit patches to Gerrit, click
[here](https://wiki.opencord.org/display/CORD/Getting+the+Source+Code).
For a general introduction to ways you can participate and contribute
to the project, check out the
[CORD wiki](https://wiki.opencord.org/display/CORD/Contributing+to+CORD).
