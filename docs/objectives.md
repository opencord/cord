# CORD Repo Requirements and Design

## Two Main Objectives

**Trying CORD Must be a Pleasant Experience**

1. Very pleasant first impression for shrink-wrapped "copy-paste" trial
   * 5-10 simple commands
   * 1-2 verified prerequisites
   * <60 minutes)
1. One/two relevant baked-in use-case(s)
1. A few supported target environments to chose from (see below)

**Extending, customizing CORD should be well supported**

1. Straightforward to customize and extend
1. Customizations, extensions can be implemented in their own repo(s) to allow their own SCM by user, independent of CORD CI/CD repos
1. Tutorials on-line (as well as embedded in the top-level repo) provides step-by-step guidance

## Definitions

[illustration to be added to further explain these:]

* Dev host
* Dev env (may be a VM on the dev host)
* Target (deployment) environments
* Upstream artifacts
* Upstream artifact repo(s)
* Result/staged artifact repo
* Replicated local repo
* Build phase/process
* Deployment phase/process
  * Seed stage
  * Push stage
  * Local (pull) stage
* Use-case phase
* Clean-up processes


## Detailed Short-Term Requirements

These requirements are to support the intended experience outlined above:

* Supported environments for dev host:
  * Mac OS X
  * Linux
  * [Possibly Windows - lower prio, but it may be feasible due to the vagrant/external deployment models]
* Supported target (deployment) configurations [lets narrow this down for 1st release]:
  * all-in-one on local VM (Vagrant)
  * all-in-one IP-accessible bare-metal server (with Ubuntu 14.04LTS pre-installed)
  * all-in-one AWS node, pre-instantiated with Ubuntu 14.04LTS
  * all-in-one AWS node, automated pre-instantiation (needs AWS credentials, default region, but can be overridden, pem file, etc.)
  * few-server, server-only, distributed deployment, local physical servers with given IP
  * few-server, AWS, remote-deployed with auto-created nodes
  * real-pod - config 1  
  * real-pod - config 2
  * real-pod - config 3  
* Trial mode should have minimalistic prerequisites on the development host:
  * git - to clone the top-level repo
  * vagrant - to bring up the development environment, and also as deployment target
* Trial mode should allow host to be cleaned up (no trace left if user decides to wipe)
* Example steps to achieve above goal
  * Step 1: git clone <opencord repo>
  * Step 2: cd <repo>
  * Step 3: vagrant up cord-devenv  # may take a few minutes for the 1st time
  * Step 4: vagrant ssh cord-devenv
  * Step 5: cd \<repo>
  * Step 6: \<config target>
  * Step 7: \<deploy to target> # may take a few times ten minutes for the 1st time
* In addition to vagrant-based Linux dev env, MAC OS X shall be supported as native dev env too (albeit with more setup effort, which shall be well documented too)
* Consistent, clean, informative console feedback as the deployment progresses
* All assumption are verified (prerequisites, version numbers, etc.)
* Informative, helpful, consistent error messages that help to diagnose the problem and to make progress
* Allow continuation of deployment process in case of error disrupted previous run (should not need to wipe everything)
  * Idempotent steps as much as possible
* Easy full re-deployment after changes made in local devenv shall be supported (and be fast)
* Embedded documentation, but also available on-line
* All upstream artifacts shall be version-controlled, traceable and verifiable (md5, sha1 or sha256)
  * Upstream includes:
    * Vagrant box
    * Docker images
    * git source repos
    * [git binary artifacts]
    * Maven repos
    * Python/pip repos
    * Debian repos
* Upstream references shall be configurable
* We shall support the creation and the use of controlled local artifact repositories which can contain all upstream dependencies
  * To support isolated lab environments
  * To allow cascading, connected (recursive) CI/CD pipelines
  * Best would be to consolidate all these formats into one packaging and deployment format: docker image/container
* When/if upstream points to an intranet repo, deployment process must not require Internet access (only access to the local artifact repo)
* Rely on DevOps 2.0 latest/best practices:
  * Not to reinvent the wheel
  * Allow people to be self-sufficient (using their modern skills)
  * Will make our job easier: no need to explain; we can point to contemporary docs
* Number of git repos involved in CORD deployment should be "healthy"
  * One top-level CI/CD repo to allow above experience
  * It may check out a few additional sub-repos automatically
  * Sub-repos should be used for truly self-contained projects:
    * Where loose coupling with other projects is really desirable
    * When there repo lines up naturally with team ownership
    * When project is useful without the rest of the CORD ensemble
* Three domains of configuration:
  * Source of upstream prerequisites
  * Target deployment environment
  * Deployed use-case
* Multi-server (N server) deployment should not require to copy all artifacts remotely N time, but rather a one-time push/pull of such artifacts to a local repo, and additional servers shall pull from the local repo.
* Well-supported and well-documented manual steps for the following work-flows:
  * Dev host: Verify pre-requisites on dev host
  * Dev host or dev env: Pull down or update local top-level repo
  * Dev host: Build development env
  * Dev host: start/stop dev env (once it is built)
  * Dev env: Pull down all prerequisites
  * Dev env: Update prerequisites after updating top-level repo (or modifying upstream configs)
  * Dev env: Build all target artifacts (whatever needs building)
  * Dev env: Run pre-deployment tests (if any)
  * Dev env: Select server and start it if needed (docker image with docker registry)
  * Dev env: Push all target artifacts to target artifact repo (with optional tag)
  * Dev env: Select / configure target (manual config of target descriptor files)
  * Dev env: Verify target readiness
  * Dev env: Deploy to select target (from optional tag)
  * Target: Execute select post-deploy test suite(s) on select target
  * Dev env or target: Destroy/wipe target (as applicable)

 
## Detailed Longer-term Requirements

* Supported evaluation use-cases shall include:
  * Testing HA scenarios
  * Testing scale-out and scale-in scenarios
  * Testing upgrade process scenarios
  * Numerical tests (performance tests)
  * [Posting tests to test report server]
* The CI/CD environment shall be embedded into the CORD repo
* The CI/CD environment shall support easy setup of:
  * Multiple deployment stations (for various types of tests, such as post-commit regression tests, daily smoke- and performance tests)
  * Local or remote git repo for SCM
  * Self-contained jenkins profile(s) for automating CI/CD pipeline (useful/meaningful as is, but customizable by user)

 
# Design

[to be flashed out once we ratify the requirements]


## Open Issues

* On AWS we need a container-only use-case (absolutely no VMs) - is that feasible?
* Same is needed in a Vagrant-based local simulated env - is that feasible?
* Role of local Orchestrator in deployment and management of the basic infrastructure - we believe that this shall be minimized to avoid self-management loop. Specifically, local Orchestrator shall not manage what it depends on for its own functionality
