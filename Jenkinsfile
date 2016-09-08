
node ('build') {
   // Mark the code checkout 'stage'....
   stage 'Checkout'
   // Get cord from opencord repo
   checkout([$class: 'RepoScm', currentBranch: true, manifestBranch: 'master', manifestRepositoryUrl: 'https://gerrit.opencord.org/manifest', quiet: true])
   
   stage 'chdir to build'
   dir('build') {
        try {
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
