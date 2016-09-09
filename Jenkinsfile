node ('build') {
   stage 'chdir to build'
   dir('build') {
        try {
            stage 'Login to Maas'
            sh "maas login maas http://10.90.0.2/MAAS/api/2.0 ${apiKey}"
            
            stage 'Release head node'
            sh "maas maas machine release ${systemId}"
            sleep 180
            
            stage 'Acquire head Node'
            sh 'maas maas machines allocate'
            
            stage 'Deploy head node'
            sh "maas maas machine deploy ${systemId}"
            
            sleep 750
            
            stage 'Bring up vagrant box'
            sh 'vagrant up corddev'

            stage 'Fetch build elements'
            sh 'vagrant ssh -c "cd /cord/build; ./gradlew fetch" corddev'

            stage 'Build Images'
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
