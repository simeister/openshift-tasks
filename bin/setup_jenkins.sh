#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
# TBD
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true -n ${GUID}-jenkins  
oc set resources dc/jenkins --limits=memory=4Gi,cpu=4 --requests=memory=2Gi,cpu=2 -n ${GUID}-jenkins 

# Create custom agent container image with skopeo
# TBD
oc new-build  -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n USER root\nRUN yum -y install skopeo && yum clean all\n USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins  

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
# TBD
# oc new-app https://github.com/simeister/openshift-tasks --context-dir=openshift-tasks -n ${GUID}-jenkins 
# Grading pipeline uses tasks-pipeline
# works only if executed on own VM: oc create -f ../tasks-pipeline.yaml -n ${GUID}-jenkins
echo "apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  labels:
    app: openshift-tasks
  name: tasks-pipeline
  namespace: ${GUID}-jenkins
spec:
  failedBuildsHistoryLimit: 5
  nodeSelector: {}
  output: {}
  postCommit: {}
  resources: {}
  runPolicy: Serial
  source:
    contextDir: openshift-tasks
    git:
      ref: master
      uri: '${REPO}'
    type: Git
  strategy:
    jenkinsPipelineStrategy:
      jenkinsfilePath: Jenkinsfile 
    type: JenkinsPipeline
  successfulBuildsHistoryLimit: 5
  triggers:
    - github:
        secret: 7lzkp3hmB9hkqi6Zq5dr
      type: GitHub
    - generic:
        secret: 1j6rW4jcfUrMIfvzS244
      type: Generic
    - type: ConfigChange
status:
  lastVersion: 1" | oc create -f - -n ${GUID}-jenkins
oc set env bc/tasks-pipeline GUID=${GUID} -n ${GUID}-jenkins
# oc start-build tasks-pipeline -n ${GUID}-jenkins
# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
