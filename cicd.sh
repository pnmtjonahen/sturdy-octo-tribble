#!/bin/bash
# start and stop cicd applications

DOCKER_NETWORK=local-sb-network

function start_jenkins {
    docker run -d -u root -p 18080:8080 -v jenkins-data:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock --network=$DOCKER_NETWORK --restart=unless-stopped --name=jenkins jenkinsci/blueocean
}

function start_gogs {
    docker run -d -p 8300:3000 -p 8322:22 -v gogs_data:/data --network=$DOCKER_NETWORK --restart=unless-stopped --name=gogs gogs/gogs
}

function start_sonar {
    docker run -d -p 9000:9000 -v sonarqube_conf:/opt/sonarqube/conf -v sonarqube_data:/opt/sonarqube/data -v sonarqube_logs:/opt/sonarqube/logs -v sonarqube_extentions:/opt/sonarqube/extensions --network=$DOCKER_NETWORK --restart=unless-stopped --name=sonarqube sonarqube
}

function start_nexus3 {
    docker run -d -p 18081:8081 -p 18082:8082 -p 18083:8083 -v nexus3_data:/nexus-data --network=$DOCKER_NETWORK --restart=unless-stopped --name=nexus3 sonatype/nexus3
}

case $1 in
   'start' )
        case $2 in
            'all' )
              echo "Starting all services..."
              start_jenkins
              start_sonar
              start_nexus3
              start_gogs
            ;;
            'jenkins' )
              start_jenkins
            ;;
            'sonar' )
              start_sonar
            ;;
            'nexus' )
              start_nexus3
            ;;
            'gogs' )
              start_gogs
            ;;
        esac
    ;;
   'stop' )
       case $2 in
           'all' )
           echo "Stopping all services..."
           docker stop jenkins
           docker stop sonar
           docker stop nexus3
           docker stop gogs
         ;;
         * )
          docker stop $2
         ;;
       esac
    ;;
    'rm' )
        case $2 in
            'all' )
            echo "Removing all services..."
            docker rm jenkins
            docker rm sonar
            docker rm nexus3
            docker rm gogs
          ;;
          * )
           docker rm $2
          ;;
        esac
     ;;
     * )
      echo stop,start,rm docker containers
     ;;
esac
