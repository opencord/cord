#Getting the CORD source code

##Install repo
Repo is a tool from Google that help us managing the code base.

```
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/repo && \
sudo chmod a+x repo && \
sudo cp repo /usr/bin
```

##Download the CORD repositories

<pre><code>mkdir ~/cord && \
cd ~/cord && \
repo init -u https://gerrit.opencord.org/manifest -b {{ book.branch }} && \
repo sync</code></pre>

>NOTE: master is used as example. You can substitute it with your favorite branch, for example cord-4.0 or cord-3.0. You can also use a "flavor" specific manifests such as “mcord” or “ecord”. The flavor you use here is not correlated to the profile you will choose to run later but it is suggested that you use the corresponding manifest for the deployment you want. AN example is to use the “ecord” profile and then deploy the ecord.yml service\_profile. 

When this is complete, a listing (`ls`) inside this directory should yield output similar to:

```
ls -F
build/         incubator/     onos-apps/     orchestration/ test/
```
