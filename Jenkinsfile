def filename = 'manifest-${branch}.xml'

node ('master') {
       checkout changelog: false, poll: false, scm: [$class: 'RepoScm', currentBranch: true, manifestBranch: params.branch, manifestRepositoryUrl: 'https://gerrit.opencord.org/manifest', quiet: true]

       stage 'Generate and Copy Manifest file'
       sh returnStdout: true, script: 'repo manifest -r -o ' + filename
       sh returnStdout: true, script: 'cp ' + filename + ' ' + env.JENKINS_HOME + '/tmp'
}

timeout (time: 240) {
    node ("${devNodeJenkinsName}") {
       stage 'Checkout cord repo'
       checkout changelog: false, poll: false, scm: [$class: 'RepoScm', currentBranch: true, manifestBranch: params.branch, manifestRepositoryUrl: 'https://gerrit.opencord.org/manifest', quiet: true]

       dir('build') {
            stage 'Redeploy head node and Build Vagrant box'
            try {
                parallel(
                    maasOps: {
                        sh "maas login maas http://${maasHeadIP}/MAAS/api/2.0 ${apiKey}"
                        sh "maas maas machine release ${headNodeMAASSystemId}"

                        timeout(time: 15) {
                            waitUntil {
                               try {
                                    sh "maas maas machine read ${headNodeMAASSystemId} | grep Ready"
                                    return true
                                } catch (exception) {
                                    return false
                                }
                            }
                        }

                        sh 'maas maas machines allocate'
                        sh "maas maas machine deploy ${headNodeMAASSystemId}"

                        timeout(time: 30) {
                            waitUntil {
                               try {
                                    sh "maas maas machine read ${headNodeMAASSystemId} | grep Deployed"
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

                stage 'Fetch CORD packages'
                sh 'vagrant ssh -c "cd /cord/build; ./gradlew fetch" corddev'

                stage 'Build CORD Images'
                sh 'vagrant ssh -c "cd /cord/build; ./gradlew buildImages" corddev'

                stage 'Downloading CORD POD configuration'
                sh 'vagrant ssh -c "cd /cord/build/config; git clone ${podConfigRepoUrl}" corddev'

                stage 'Publish to headnode'
                sh 'vagrant ssh -c "cd /cord/build; ./gradlew -PtargetReg=${headNodeIP}:5000 -PdeployConfig=config/pod-configs/${podConfigFileName} publish" corddev'

                stage 'Deploy'
                sh 'vagrant ssh -c "cd /cord/build; ./gradlew -PtargetReg=${headNodeIP}:5000 -PdeployConfig=config/pod-configs/${podConfigFileName} deploy" corddev'

		stage 'Power cycle compute nodes'
                parallel(
                    compute_1: {
                        sh 'ipmitool -U ${computeNode1IPMIUser} -P ${computeNode1IPMIPass} -H ${computeNode1IPMIIP} power cycle'
                    }, compute_2: {
                        sh 'ipmitool -U ${computeNode2IPMIUser} -P ${computeNode2IPMIPass} -H ${computeNode2IPMIIP} power cycle'
                    }, failFast : true
                )

                stage 'Wait for compute nodes to get deployed'
                sh 'ssh-keygen -f "/home/ubuntu/.ssh/known_hosts" -R ${headNodeIP}'
                def cordapikey = sh(returnStdout: true, script: "sshpass -p ${headNodePass} ssh -oStrictHostKeyChecking=no -l ${headNodeUser} ${headNodeIP} sudo maas-region-admin apikey --username cord")
                sh "sshpass -p ${headNodePass} ssh -oStrictHostKeyChecking=no -l ${headNodeUser} ${headNodeIP} maas login pod-maas http://${headNodeIP}/MAAS/api/1.0 $cordapikey"
                timeout(time: 45) {
                    waitUntil {
                        try {
                            num = sh(returnStdout: true, script: "sshpass -p ${headNodePass} ssh -l ${headNodeUser} ${headNodeIP} maas pod-maas nodes list | grep Deployed | wc -l").trim()
                            return num == '2'
                        } catch (exception) {
                            return false
                        }
                    }
                }

                stage 'Wait for computes nodes to be provisioned'
                ip = sh (returnStdout: true, script:"sshpass -p ${headNodePass} ssh -oStrictHostKeyChecking=no -l ${headNodeUser} ${headNodeIP} docker inspect --format '{{.NetworkSettings.Networks.maas_default.IPAddress}}'  provisioner").trim()
                timeout(time:45) {
                    waitUntil {
                        try {
                            out = sh (returnStdout: true, script:"sshpass -p ${headNodePass} ssh -oStrictHostKeyChecking=no -l ${headNodeUser} ${headNodeIP} curl -sS http://$ip:4243/provision/ | jq -c '.[] | select(.status | contains(2))'").trim()
                            return out != ""
                        } catch (exception) {
                            return false
                        }
                    }
                }

                stage 'Trigger Build'
                url = 'https://jenkins.opencord.org/job/release-build/job/' + params.branch + '/build'
                httpRequest authentication: 'auto-release', httpMode: 'POST', url: url, validResponseCodes: '201'

                currentBuild.result = 'SUCCESS'
            } catch (err) {
                currentBuild.result = 'FAILURE'
                step([$class: 'Mailer', notifyEveryUnstableBuild: true, recipients: "${notificationEmail}", sendToIndividuals: false])
            } finally {
                sh 'vagrant destroy -f corddev'
                sh 'rm -rf config/pod-configs'
            }
            echo "RESULT: ${currentBuild.result}"
       }

    }
}
