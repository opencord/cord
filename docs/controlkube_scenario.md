# How to use the Controlkube scenario

The Controlkube scenario is a new scenario in CORD 5.0 created
specifically for a kubernetes deployment. It currently, only works on Linux hosts.

It creates a three VM virtual cluster with Ubuntu 16.04 deployed
and the latest version kubernetes (1.9.x as of this writing) installed
using [Kubespray](https://github.com/kubernetes-incubator/kubespray). We
also install [Helm](https://github.com/kubernetes/helm) that serves as
kubernetes application package manager and installer. This consists of
two components. The first component is "Tiller", a server component
running in kubernetes and keeping track of Helm installs. The second
component is the Helm command line client (called “helm”) that is
installed on the host running the VMs. The Kubernetes client
application [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)
is also installed on the host running the VMs.

The CORD platform team is standardizing on Helm as the official tool to
deploy all platform artifacts (XOS, ONOS, R-CORD, M-CORD, E-CORD, VOLTHA).
But if you, as the user, are comfortable using kubectl to manage your
deployments, you are welcome to do so.

You should run the following commands on a clean Linux machine in the
home directory to install this scenario:

```shell
# Pull down cord-bootstrap.sh script and start a tmux session
curl -o ~/cord-bootstrap.sh \
https://raw.githubusercontent.com/opencord/cord/{{ book.branch }}/scripts/cord-bootstrap.sh
chmod +x cord-bootstrap.sh
tmux
```

```shell
# Install CORD with kubernetes and XOS Helm chart (this is a single command wordwrapped)
time bash ./cord-bootstrap.sh -v -x -t "PODCONFIG=rcord-controlkube.yml config" \
-t "build" |& tee -a ~/setup.log
```

Once this command finishes successfully, you will find the XOS Core
helm chart running. You can verify this by running the following command.

`helm ls`

This will list all the the helm charts running in Kubernetes currently.
The XOS Core Helm chart has been integrated into the platform-install
project as an ansible playbook (~/cord/build/platform-install/roles/cord-helm-charts).
This role renders the helm chart before deploying it. If you would
like to see what a typical helm chart would look like, please check
out helm chart examples on github:

[https://github.com/kubernetes/helm/tree/master/docs/examples](https://github.com/kubernetes/helm/tree/master/docs/examples)

[https://github.com/kubernetes/charts](https://github.com/kubernetes/charts)

There are also several tutorials on the web explaining Helm chart
development. Here is one we found useful:

[https://medium.com/@gajus/the-missing-ci-cd-kubernetes-component-helm-package-manager-1fe002aac680](https://medium.com/@gajus/the-missing-ci-cd-kubernetes-component-helm-package-manager-1fe002aac680)

