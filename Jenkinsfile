node ('build') {
   stage 'Checkout cord repo'
   checkout changelog: false, poll: false, scm: [$class: 'RepoScm', currentBranch: true, manifestRepositoryUrl: 'https://gerrit.opencord.org/manifest', quiet: true]
   dir('build') {
        stage 'Redeploy head node and Build Vagrant box'
        try {
            parallel( 
                maasOps: {
                    sh "maas login maas http://10.90.0.2/MAAS/api/2.0 ${apiKey}"
                    sh "maas maas machine release ${systemId}"
                    
                    timeout(time: 15) {
                        waitUntil {
                           try {
                                sh "maas maas machine read ${systemId} | grep Ready"
                                return true
                            } catch (exception) {
                                return false
                            }
                        }
                    }
                    
                    sh 'maas maas machines allocate'
                    sh "maas maas machine deploy ${systemId}"
                    
                    timeout(time: 30) {
                        waitUntil {
                           try {
                                sh "maas maas machine read ${systemId} | grep Deployed"
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

            stage 'Publish to headnode'
            sh 'vagrant ssh -c "cd /cord/build; ./gradlew -PtargetReg=10.90.0.251:5000 -PdeployConfig=config/onlab_develop_pod.yml publish" corddev'

            stage 'Deploy'
            sh 'vagrant ssh -c "cd /cord/build; ./gradlew -PtargetReg=10.90.0.251:5000 -PdeployConfig=config/onlab_develop_pod.yml deploy" corddev'

            stage 'Power cycle compute nodes'
            parallel(
                compute_1: {
                    sh "ipmitool -U admin -P admin -H 10.90.0.10 power cycle"
                }, compute_2: {
                    sh "ipmitool -U admin -P admin -H 10.90.0.11 power cycle"
                }, failfast : true
            )

            stage 'Wait for compute nodes to get deployed'
            def cordapikey = sh(returnStdout: true, script: 'sshpass -p ${headnodepass} ssh -oStrictHostKeyChecking=no -l ${headnodeuser} 10.90.0.251 sudo maas-region-admin apikey --username cord') 
            sh 'sshpass -p ${headnodepass} ssh -oStrictHostKeyChecking=no -l ${headnodeuser} 10.90.0.251 maas login pod-maas http://10.90.0.251/MAAS/api/1.0 $cordapikey'
            timeout(time: 30) {
                waitUntil {
                    try {
                        num = sh(returnStdout: true, script: 'sshpass -p ${headnodepass} ssh -l ${headnodeuser} 10.90.0.251  maas pod-maas nodes list | grep Deployed')
                        return num == 2
                    } catch (exception) {
                        return false
                    }
                }
            }

            currentBuild.result = 'SUCCESS'
            step([$class: 'Mailer', recipients: 'cord-dev@opencord.org', sendToIndividuals: false])
        } catch (err) {
            currentBuild.result = 'FAILURE'
            step([$class: 'Mailer', notifyEveryUnstableBuild: true, recipients: 'cord-dev@opencord.org', sendToIndividuals: false])
        } finally {
            sh 'vagrant destroy -f corddev'
        }
        echo "RESULT: ${currentBuild.result}"
   }

}
