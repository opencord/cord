def filename = 'manifest-${branch}.xml'
def manifestUrl = 'https://gerrit.opencord.org/manifest'
def config = null;

node ('master') {
    checkout changelog: false, poll: false, scm: [$class: 'RepoScm', currentBranch: true, manifestBranch: params.branch, manifestRepositoryUrl: "${manifestUrl}", quiet: true]

    stage ("Generate and Copy Manifest file") {
        sh returnStdout: true, script: 'repo manifest -r -o ' + filename
        sh returnStdout: true, script: 'cp ' + filename + ' ' + env.JENKINS_HOME + '/tmp'
    }

    stage ("Parse deployment configuration file") {
        sh returnStdout: true, script: 'rm -rf ${configRepoBaseDir}'
        sh returnStdout: true, script: 'git clone -b ${branch} ${configRepoUrl}'
        config = readYaml file: "${configRepoBaseDir}${configRepoFile}"
    }
}

node ("${config.dev_node.name}") {
    timeout (time: 240) {
        stage ('Checkout cord repo') {
            checkout changelog: false, poll: false, scm: [$class: 'RepoScm', currentBranch: true, manifestBranch: params.branch, manifestRepositoryUrl: "${manifestUrl}", quiet: true]
        }

        try {
            dir('build') {
                stage ("Re-deploy head node and Build Vagrant box") {
                    parallel(
                        maasOps: {
                            sh "maas login maas http://${config.maas.ip}/MAAS/api/2.0 ${config.maas.api_key}"
                            sh "maas maas machine release ${config.maas.head_system_id}"

                            timeout(time: 15) {
                                waitUntil {
                                   try {
                                        sh "maas maas machine read ${config.maas.head_system_id} | grep Ready"
                                        return true
                                    } catch (exception) {
                                        return false
                                    }
                                }
                            }

                            sh 'maas maas machines allocate'
                            sh "maas maas machine deploy ${config.maas.head_system_id}"

                            timeout(time: 30) {
                                waitUntil {
                                   try {
                                        sh "maas maas machine read ${config.maas.head_system_id} | grep Deployed"
                                        return true
                                    } catch (exception) {
                                        return false
                                    }
                                }
                            }

                        }, vagrantOps: {
                            sh 'vagrant up corddev'
                        }, failFast : true
                    )
                }

                if (config.fabric_switches != null) {
                    stage("Reserve IPs for fabric switches") {
                        for(int i=0; i < config.fabric_switches.size(); i++) {
                            def str = createMACIPbindingStr(i+1,
                                                           "${config.fabric_switches[i].mac}",
                                                           "${config.fabric_switches[i].ip}")
                            sh "echo $str >> maas/roles/maas/files/dhcpd.reservations"
                        }
                    }
                }

                stage ("Fetch CORD packages") {
                    sh "vagrant ssh -c \"cd /opt/cord/build; ./gradlew fetch\" corddev"
                }

                stage ("Build CORD Images") {
                    sh "vagrant ssh -c \"cd /opt/cord/build; ./gradlew buildImages\" corddev"
                }

                stage ("Downloading CORD POD configuration") {
                    sh "vagrant ssh -c \"cd /opt/cord/build/config; git clone -b ${branch} ${config.pod_config.repo_url}\" corddev"
                }

                stage ("Publish to headnode") {
                    sh "vagrant ssh -c \"cd /opt/cord/build; ./gradlew -PtargetReg=${config.head.ip}:5000 -PdeployConfig=config/pod-configs/${config.pod_config.file_name} publish\" corddev"
                }

                stage ("Deploy") {
                    sh "vagrant ssh -c \"cd /opt/cord/build; ./gradlew -PtargetReg=${config.head.ip}:5000 -PdeployConfig=config/pod-configs/${config.pod_config.file_name} deploy\" corddev"
                }

                if (config.compute_nodes != null) {

                    stage ("Power cycle compute nodes") {
                        for(int i=0; i < config.compute_nodes.size(); i++) {
                            sh "ipmitool -U ${config.compute_nodes[i].ipmi.user} -P ${config.compute_nodes[i].ipmi.pass} -H ${config.compute_nodes[i].ipmi.ip} power cycle"
                        }
                    }

                    stage ("Wait for compute nodes to get deployed") {
                        sh "ssh-keygen -f /home/${config.dev_node.user}/.ssh/known_hosts -R ${config.head.ip}"
                        def cordApiKey = runCmd("${config.head.ip}",
                                                "${config.head.user}",
                                                "${config.head.pass}",
                                                "sudo maas-region-admin apikey --username ${config.head.user}")
                        runCmd("${config.head.ip}",
                               "${config.head.user}",
                               "${config.head.pass}",
                               "maas login pod-maas http://${config.head.ip}/MAAS/api/1.0 ${cordApiKey}")
                        timeout(time: 45) {
                            waitUntil {
                                try {
                                    num = runCmd("${config.head.ip}",
                                                 "${config.head.user}",
                                                 "${config.head.pass}",
                                                 "maas pod-maas nodes list | grep -i deployed | wc -l").trim()
                                    return num.toInteger() == config.compute_nodes.size()
                                } catch (exception) {
                                    return false
                                }
                            }
                        }
                    }

                    stage ("Wait for compute nodes to be provisioned") {
                        timeout(time:45) {
                            waitUntil {
                                try {
                                    num = runCmd("${config.head.ip}",
                                                 "${config.head.user}",
                                                 "${config.head.pass}",
                                                 "cord prov list '|' grep -i node '|' grep -i complete '|' wc -l").trim()
                                    return num.toInteger() == config.compute_nodes.size()
                                } catch (exception) {
                                    return false
                                }
                            }
                        }
                    }

                }

                if (config.fabric_switches != null) {
                    stage ("Wait for fabric switches to get deployed") {
                        for(int i=0; i < config.fabric_switches.size(); i++) {
                            runFabricCmd("${config.head.ip}",
                                         "${config.head.user}",
                                         "${config.head.pass}",
                                         "${config.fabric_switches[i].ip}",
                                         "${config.fabric_switches[i].user}",
                                         "${config.fabric_switches[i].pass}",
                                         "sudo onl-onie-boot-mode install")

                            runFabricCmd("${config.head.ip}",
                                         "${config.head.user}",
                                         "${config.head.pass}",
                                         "${config.fabric_switches[i].ip}",
                                         "${config.fabric_switches[i].user}",
                                         "${config.fabric_switches[i].pass}",
                                         "sudo reboot")
                        }
                        timeout(time: 45) {
                            waitUntil {
                                try {
                                    def harvestCompleted = runCmd("${config.head.ip}",
                                                                  "${config.head.user}",
                                                                  "${config.head.pass}",
                                                                  "cord harvest list '|' grep -i fabric '|' wc -l").trim()
                                    return harvestCompleted.toInteger() == config.fabric_switches.size()
                                } catch (exception) {
                                    return false
                                }
                            }
                        }
                    }

                    stage ("Wait for fabric switches to be provisioned") {
                        timeout(time:45) {
                            waitUntil {
                                try {
                                    def provCompleted = 0
                                    for(int i=0; i < config.fabric_switches.size(); i++) {
                                        def count = runCmd("${config.head.ip}",
                                                           "${config.head.user}",
                                                           "${config.head.pass}",
                                                           "cord prov list '|' grep -i ${config.fabric_switches[i].ip} '|' grep -i complete '|' wc -l").trim()
                                        provCompleted = provCompleted + count.toInteger()
                                    }
                                    return provCompleted == config.fabric_switches.size()
                                } catch (exception) {
                                    return false
                                }
                            }
                        }
                    }
                }
            }
            if (config.make_release == true) {
                stage ("Trigger Build") {
                    url = 'https://jenkins.opencord.org/job/release-build/job/' + params.branch + '/build'
                    httpRequest authentication: 'auto-release', httpMode: 'POST', url: url, validResponseCodes: '201'
                }
            }

            currentBuild.result = 'SUCCESS'
        } catch (err) {
            currentBuild.result = 'FAILURE'
            step([$class: 'Mailer', notifyEveryUnstableBuild: true, recipients: "${notificationEmail}", sendToIndividuals: false])
        } finally {
            sh 'cd build && vagrant destroy -f corddev'
            sh 'rm -rf *'
        }

        echo "RESULT: ${currentBuild.result}"
    }
}

/**
 * Returns a string used to bind IPs and MAC addresses, substituting the values
 * given.
 *
 * @param counter the counter used to generate the host name
 * @param mac     the MAC address to substitute
 * @param ip      the IP address to substitute
 */
def createMACIPbindingStr(counter, mac, ip) {
    return """host fabric${counter} {'\n'hardware ethernet ${mac}';''\n'fixed-address ${ip}';''\n'}"""
}

/**
 * Runs a command on a remote host using sshpass.
 *
 * @param ip      the node IP address
 * @param user    the node user name
 * @param pass    the node password
 * @param command the command to run
 * @return the output of the command
 */
def runCmd(ip, user, pass, command) {
    return sh(returnStdout: true, script: "sshpass -p ${pass} ssh -oStrictHostKeyChecking=no -l ${user} ${ip} ${command}")
}

/**
 * Runs a command on a fabric switch.
 *
 * @param headIp         the head node IP address
 * @param headUser       the head node user name
 * @param headPass       the head node password
 * @param ip             the mgmt IP of the fabric switch, reachable from the head node
 * @param user           the mgmt user name of the fabric switch
 * @param pass           the mgmt password of the fabric switch
 * @param command        the command to run on the fabric switch
 * @return the output of the command
 */
def runFabricCmd(headIp, headUser, headPass, ip, user, pass, command) {
    return sh(returnStdout: true, script: "sshpass -p ${headPass} ssh -oStrictHostKeyChecking=no -l ${headUser} ${headIp} \"sshpass -p ${pass} ssh -oStrictHostKeyChecking=no -l ${user} ${ip} ${command}\"")
}
