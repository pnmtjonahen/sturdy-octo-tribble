# Continious Integration / Continious Deployment
## A buildpipeline

![gogs](https://img.shields.io/badge/git-Gogs-blue)
![jenkins](https://img.shields.io/badge/cicd-Jenkins-blue)
![nexus3](https://img.shields.io/badge/repo-Nexus3-blue)
![sonarqube](https://img.shields.io/badge/qa-SonarQube-blue)

This repository contains scripts/guide to start a local buildpipeline. The following tools are included:
- Jenkins
- SonarQube
- Nexus3
- Gogs

All the different tools run in their own docker container.

The following decisions I made and are up to the reader to decide whether to follow or not. Reasoning is that I wanted a playground, not a production grade pipeline.

- When possible use docker volumes to store persistent data, no or minimal host mounted volumes are used.
- When possible use embedded database
- All applications are connected to the same docker network 'local-cicd-network' this allows the different applications to connect to each other by name.

Note:
When playing around or initially start the application without -d (detached) mode, it is easier to read what is happening/went wrong. If everything is working fine, stop and start all application with the -d (detached) option.

## Gogs a painless self-hosted Git services

### Installation
Dockerhub : https://hub.docker.com/r/gogs/gogs/

```bash
docker run \
      -d \
      -p 8300:3000 \
      -p 8322:22 \
      -v gogs_data:/data \
      --network=local-cicd-network \
      --restart=unless-stopped \
      --name=gogs \
      gogs/gogs
```

### Configuration
Open a browser: http://localhost:8300

On the 'Install Steps For First-time Run' change the following settings:
- Database Type : SQLite3
- SSH Port : 8322
- Application URL : http://localhost:8300
- Log Path : /data/log

And click on the 'Install Gogs' button  

When presented with the 'Sign In' page create your first account (which will become the admin account) by clicking on the 'Sign up now.' link.

You should now have your own self-hosted Git service.

### Mirror GitHub
Inspired by : https://moox.io/blog/keep-in-sync-git-repos-on-github-gitlab-bitbucket/

Not having my source code only on the self-hosted git service I wanted to have my github repositories synced with my Gogs service.
To allow easy push and pulls on both repository I added the same public SSH key to both GitHub and Gogs.

Next step is to mirror a GitHub repository in Gogs. Select create -> New Migration.

Gogs only allows for creating a mirror using HTTP/HTTPS so you need your GitHub username/password for Authorisation. Fill in the:
- Clone Address
- Need Authorization
  - Username
  - Password
- Repository Name

Use the same repository name as the mirrored repository to prevent confusion.

And click on the 'Migrate Repository' button.

You now have a mirror/copy of your GitHub hosted repository on your local Gogs instance.

To allow 'git push' on both repositories we need to set the correct remote url. As we are using a non standard ssh port the url for remote is slightly different then the default.

First (if not done already) make a local clone of the GitHub repository and add an extra remote with:

```bash
git remote set-url origin --add ssh://git@localhost:8322/{user_name}/{repository_name}.git
```

where:
- user_name is the name of the user that contains the repository
- repository_name is the name of the cloned repository


## Jenkins

Inspired by : https://jenkins.io/doc/tutorials/build-a-java-app-with-maven/
Dockerhub : https://hub.docker.com/r/jenkinsci/blueocean/

Except that we wont use a file based repository but will use a hosted repository (Gogs)

### Installation
To get jenkins installed follow the guide mentioned above. After installation and your first pipeline stop jenkins and restart with the following docker command:

```bash
docker run \
  -d \
  -u root \
  -p 18080:8080 \
  -v jenkins-data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --network=local-cicd-network \
  --restart=unless-stopped \
  --name jenkins \
  jenkinsci/blueocean
```

This will then:
- run Jenkins in the background
- restarts Jenkins unless stopped and
- removes the host based volume.

### Build your Gogs mirrored project.
First Jenkins need to be able to get the source code using git (Either via GitHub or from Gogs). As we added to both repositories the same ssh public key we can simply add a credential with the private key belonging to the public key.

Add a Jenkins file to your repository (if not already done) with the correct pipeline definition.

When creating the Multi branch pipeline adjust the 'Project Repository' from:

```
ssh://git@localhost:8322/{user_name}/{repository_name}.git
```

into

```
ssh://git@gogs/{user_name}/{repository_name}.git
```

As the Gogs repository from a Jenkins point of view is not on localhost:8322 but on gogs:22 as they are on the same docker network.

### Trigger build on push
On Jenkins install the 'Gogs Webhook Plugin' https://wiki.jenkins.io/display/JENKINS/Gogs+Webhook+Plugin

Then on Gogs repository configure the webhook (Gogs) on push only. For the payload use:
```
http://jenkins:8080/gogs-webhook/?job={job_name}
```

From a Gogs point of view Jenkins is not on localhost:18080 but on the same docker network on host name jenkins with port 8080.

If you push changed to the Gogs repo (or when you use)

## SonarQube
Dockerhub : https://hub.docker.com/_/sonarqube
### Installation

```bash
docker run \
  -d \
  -p 9000:9000 \
  -v sonarqube_conf:/opt/sonarqube/conf \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extentions:/opt/sonarqube/extensions \
  --network=local-cicd-network \
  --restart=unless-stopped \
  --name sonarqube \
  sonarqube
```

### Testing the installation.

From your local cloned repository perform a:
```bash
mvn sonar:sonar
```

This will use the default sonar location.

When adding to your pipeline script remember that sonar is running not on localhost from a jenkins point of view. But on a host called sonarqube. Define your pipeline step as follows:

```
stage('Sonar') {
  steps {
      sh 'mvn sonar:sonar -Dsonar.host.url=http://sonarqube:9000'
  }
}
```

## Nexus3

Dockerhub : https://hub.docker.com/r/sonatype/nexus3

### Installation

```bash
docker run \
  -d \
  -p 18081:8081 \
  -p 18082:8082 \
  -p 18083:8083 \
  -v nexus3_data:/nexus-data \
  --network=local-cicd-network \
  --restart=unless-stopped \
  --name nexus3 \
  sonatype/nexus3
```
### Configuration (local)

For local development we need to setup maven to use our local installed nexus as the maven central proxy.

```xml
<settings>
  <mirrors>
    <mirror>
      <!--This sends everything else to /public -->
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>http://localhost:18081/repository/maven-central/</url>
    </mirror>
  </mirrors>
  <profiles>
    <profile>
      <id>nexus</id>
      <!--Enable snapshots for the built in central repo to direct -->
      <!--all requests to nexus via the mirror -->
      <repositories>
        <repository>
          <id>central</id>
          <url>http://central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
     <pluginRepositories>
        <pluginRepository>
          <id>central</id>
          <url>http://central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
  <activeProfiles>
    <!--make the profile active all the time -->
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>
```

### Configuration (Jenkins)
For Jenkins maven builds to use the Nexus repository 2 separate changes need to be made.

First the maven agent used in the pipeline definition should also connect to the docker network. Change your Jenkins file as follows:

```
agent {
    docker {
        image 'maven:3.6.1-jdk-12'
        args '-v /root/.m2:/root/.m2 --network=local-cicd-network'
    }
}
```

This allows the maven docker image to reach the nexus host.
Next step is to actually have maven use the nexus repository. The maven docker is configured to use the local folder '/root/.m2' as its maven folder.
In that local folder add the following settings.xml file.

```xml
<settings>
  <mirrors>
    <mirror>
      <!--This sends everything else to /public -->
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>http://nexus3:8081/repository/maven-central/</url>
    </mirror>
  </mirrors>
  <profiles>
    <profile>
      <id>nexus</id>
      <!--Enable snapshots for the built in central repo to direct -->
      <!--all requests to nexus via the mirror -->
      <repositories>
        <repository>
          <id>central</id>
          <url>http://central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
     <pluginRepositories>
        <pluginRepository>
          <id>central</id>
          <url>http://central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
  <activeProfiles>
    <!--make the profile active all the time -->
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>
```

Note: Need to find a better place for the .m2 folder.
