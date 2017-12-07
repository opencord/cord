# Building Docker Images

The current CORD implementation consists of many interrelated Docker images.
Making sure that the images used in a deployment are consistent with the source
tree on disk is a challenge and required a tool,
[imagebuilder](https://github.com/opencord/cord/blob/{{ book.branch
}}/scripts/imagebuilder.py), to be developed to perform image rebuilds in a
consistent and efficient manner.

Imagebuilder is currently used for XOS and ONOS images, but not MaaS images.

While imagebuilder will pull down required images from DockerHub and build/tag
images, it does not push those images or delete obsolete ones.  These tasks are
left to other software (Ansible, Jenkins) which should take in imagebuilder's
YAML output and take the appropriate actions.

## Obtaining and rebuilding images

For the normal build process, you won't need to manually download images as the
`docker-images` make target that runs imagebuilder will automatically be run as
a part of the build process.

If you do need to rebuild images, there is a `make clean-images` target that
will force imagebuilder to be run again and images to be moved into place.

## Debugging imagebuilder

If you get a different error or  think that imagebuilder isn't working
correctly, please rerun it with the `-vv` ("very verbose") option, read through
the output carefully, and then post about the issue on the mailing list or
Slack.

If an image is not found on Dockerhub, you may see a 404 error like the
following in the logs. If this happens, imagebuilder will attempt to build the
image from scratch rather than pulling it:

```
NotFound: 404 Client Error: Not Found ("{"message":"manifest for xosproject/xos-gui-extension-builder:<hash> not found"}")
```

Run `imagebuilder.py -h` for a list of other supported arguments.

## How Imagebuilder works

The imagebuilder program performs the following steps when run:

 1. Reads the [repo manifest file](https://github.com/opencord/manifest/blob/master/default.xml)
    (checked out as `.repo/manifest`) to get a list of the CORD git repositories.

 2. Reads the [build/docker_images.yml](https://github.com/opencord/cord/blob/{{ book.branch }}/docker_images.yml)
    file and the generated `cord/build/genconfig/config.yml` file (which
    contains a `docker_image_whitelist` list from the scenario), to determine
    which containers are needed for this POD configuration.

 3. For every container that is needed, reads the Dockerfile and determines if
    any parent images are needed, and creates a tree to order image building.

 4. Determines which images need to be rebuilt based on:

   - Whether the image exists and is has current tags added to it.
   - If the Docker build context is *dirty* or differs (is on a different
     branch) from the git tag specified in the repo manifest
   - If the image's parent (or grandparent, etc.) needs to be rebuilt

 5. Using this information downloads (pulls) or builds images as needed in a
    way that is consistent with the CORD source that is on disk.  If an image
    build is needed, the Docker output of that build is saved to
    `build/image_logs` on the system where Imagebuilder executes (the
    `buildhost` in inventory).

 6. Tags the image with the `candidate` and (if clean) git hash tags.

 7. Creates a YAML output file that describes the work it performed, for later
    use (pushing images, retagging, etc.), and optional a graphviz `.dot` graph
    file showing the relationships between images.

## Image Tagging

CORD container images frequently have multiple tags. The two most common ones
are:

 * The string `candidate`, which says that the container is ready to be
   deployed on a CORD POD
 * The git commit hash, which is either pulled from DockerHub, or applied when
   a container is built from an untouched (according to git) source tree.
   Images built from a modified source tree will not be tagged in this way.

Imagebuilder use this git hash tag as well as labels on the image of the git
repos of parent images to determine whether an image is correctly built from
the checked out source tree.

## Image labels

Imagebuilder uses a Docker label scheme to determine whether an image needs to
be rebuilt, which is added to the image when it is built.  Docker images used
in CORD must apply labels in their Dockerfiles which are specified by
[label-schema.org](http://label-schema.org) - see there for examples, and below
for a few notes that clear up the ambiguity within that spec.

Required labels for every CORD image:

 - `org.label-schema.version`
 - `org.label-schema.name`
 - `org.label-schema.vcs-url`
 - `org.label-schema.build-date`

Required for clean builds:

 - `org.label-schema.version` : *git branch name, ex: `opencord/master`,
   `opencord/cord-4.0`, , etc.*
 - `org.label-schema.vcs-ref` : *the full 40 character SHA-1 git commit hash,
   not shortened*

Required for dirty builds:

 - `org.label-schema.version` : *set to the string `dirty` if there is any
   differences from the master commit to the build context (either on a
   different branch, or untracked/changed files in context)*
 - `org.label-schema.vcs-ref` - *set to a commit hash if build context is clean
   (ie, on another unnamed branch/patchset), or the empty string if the build
   context contains untracked/changed files.*

For images that use components from another repo (like chameleon being
integrated with the XOS containers, or maven repo which contains artifacts from
multiple onos-apps repos), the following labels should be set for every
sub-component, with the repo name (same as org.label-schema.name) replacing
`<reponame>`, and the value being the same value as the label-schema
one would be:

 - `org.opencord.component.<reponame>.version`
 - `org.opencord.component.<reponame>.vcs-ref`
 - `org.opencord.component.<reponame>.vcs-url`

These labels are applied by using the `ARG` and `LABEL` option in the
Dockerfile. The following is an example set of labels for an image that uses
files from the chameleon and XOS repositories as components:

```
# Label image
ARG org_label_schema_schema_version=1.0
ARG org_label_schema_name=openstack-synchronizer
ARG org_label_schema_version=unknown
ARG org_label_schema_vcs_url=unknown
ARG org_label_schema_vcs_ref=unknown
ARG org_label_schema_build_date=unknown
ARG org_opencord_vcs_commit_date=unknown
ARG org_opencord_component_chameleon_version=unknown
ARG org_opencord_component_chameleon_vcs_url=unknown
ARG org_opencord_component_chameleon_vcs_ref=unknown
ARG org_opencord_component_xos_version=unknown
ARG org_opencord_component_xos_vcs_url=unknown
ARG org_opencord_component_xos_vcs_ref=unknown

LABEL org.label-schema.schema-version=$org_label_schema_schema_version \
      org.label-schema.name=$org_label_schema_name \
      org.label-schema.version=$org_label_schema_version \
      org.label-schema.vcs-url=$org_label_schema_vcs_url \
      org.label-schema.vcs-ref=$org_label_schema_vcs_ref \
      org.label-schema.build-date=$org_label_schema_build_date \
      org.opencord.vcs-commit-date=$org_opencord_vcs_commit_date \
      org.opencord.component.chameleon.version=$org_opencord_component_chameleon_version \
      org.opencord.component.chameleon.vcs-url=$org_opencord_component_chameleon_vcs_url \
      org.opencord.component.chameleon.vcs-ref=$org_opencord_component_chameleon_vcs_ref \
      org.opencord.component.xos.version=$org_opencord_component_xos_version \
      org.opencord.component.xos.vcs-url=$org_opencord_component_xos_vcs_url \
      org.opencord.component.xos.vcs-ref=$org_opencord_component_xos_vcs_ref
```

Labels on a built image can be seen by running `docker inspect <image name or id>`

## Adding a new Docker image to CORD

There are a few cases when an image would be needed to be added to CORD during
the development process.

### Adding an image developed outside of CORD

There are cases where a 3rd party image developed outside of CORD may be
needed. This is the case with ONOS, Redis, and a few other pieces of software
that are already containerized, and we deploy as-is (or with minor
modifications).

To do this, add the full name of the image, including a version tag, to the
`https://github.com/opencord/cord/blob/{{ book.branch }}/docker_images.yml`
file, and to `docker_image_whitelist` list in the
`scenarios/<scenario name>/config.yml` file.

These images will be retagged with a `candidate` tag after being pulled.

### Adding a synchronizer image

Adding a synchronizer image is usually as simple as adding it to the
`buildable_images` list in the `docker_images.yml` file (see that file for the
), then making sure the image name is listed in the `docker_image_whitelist`
list in the `scenarios/<scenario name>/config.yml` file.

If you are adding a new service that is not in the repo manifest yet, you may
have to your service's directory to the `.repo/manifest.xml` file and then list
it in `build/docker_images.yml`, so it will then build the  synchronizer image
locally.

### Adding other CORD images

If you want imagebuilder to build an image from a Dockerfile somewhere in the
CORD source tree, you need to add it to the `buildable_images` list in the
`docker_images.yml` file (see that file for the specific format), then making
sure the image name is listed in the `docker_image_whitelist` list in the
`scenarios/<scenario name>/config.yml` file.

Note that you don't need to add external parent images to the
`pull_only_images` in this manner - those are determined by the `FROM` line in
`Dockerfile`

## Automating image builds

There is a [Jenkinsfile.imagebuilder](https://github.com/opencord/cord/blob/{{
book.branch }}/Jenkinsfile.imagebuilder) that can be run in a Jenkins
instance and will build and push images to DockerHub. This is how the CORD
team pre-builds and publishes images for public use.

