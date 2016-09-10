node ('build') {
   stage 'Checkout cord repo'
   checkout changelog: false, poll: false, scm: [$class: 'RepoScm', currentBranch: true, manifestRepositoryUrl: 'https://gerrit.opencord.org/manifest', quiet: true]
   stage 'chdir to build'
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

            currentBuild.result = 'SUCCESS'
        } catch (err) {
            currentBuild.result = 'FAILURE'
            step([$class: 'Mailer', notifyEveryUnstableBuild: true, recipients: 'ali@onlab.us', sendToIndividuals: false])
        } finally {
            sh 'vagrant destroy -f corddev'
        }
        echo "RESULT: ${currentBuild.result}"
   }

}
