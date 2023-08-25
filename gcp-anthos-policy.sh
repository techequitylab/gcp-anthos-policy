#!/bin/bash
# 
# Copyright 2019 Shiyghan Navti. Email shiyghan@gmail.com
# 
#################################################################################
##############          Explore Anthos Config Management          ###############
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-anthos-policy > /dev/null 2>&1
export PROJDIR=`pwd`/gcp-anthos-policy
export SCRIPTNAME=gcp-anthos-policy.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_CLUSTER=anthos-gke-cluster
export GCP_REGION=us-central1
export GCP_ZONE=us-central1-a
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
===============================================
Menu for Exploring Anthos Config Management   
-----------------------------------------------
Please enter number to select your choice:
(1) Enable APIs
(2) Create GKE cluster 
(3) Install operator  
(4) Setup repositories
(5) Apply operator
(6) Explore config management
(7) Explore policy controller
(G) Launch user guide
(Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_CLUSTER=$GCP_CLUSTER
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_CLUSTER=$GCP_CLUSTER
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable anthosconfigmanagement.googleapis.com container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com sql-component.googleapis.com sqladmin.googleapis.com --project \$GCP_PROJECT # to enable APIs" | pv -qL 100 
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ gcloud services enable anthosconfigmanagement.googleapis.com container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com sql-component.googleapis.com sqladmin.googleapis.com --project $GCP_PROJECT # to enable APIs" | pv -qL 100
    gcloud services enable anthosconfigmanagement.googleapis.com container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com sql-component.googleapis.com sqladmin.googleapis.com --project $GCP_PROJECT
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"   
    echo
    echo "$ gcloud beta container clusters create \$GCP_CLUSTER --zone \$GCP_ZONE --machine-type e2-standard-2 --num-nodes 4 --spot  --enable-binauthz=PROJECT_SINGLETON_POLICY_ENFORCE --project \$GCP_PROJECT # to create cluster" | pv -qL 100
    echo      
    echo "$ gcloud container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE --project \$GCP_PROJECT # to retrieve credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable user to set RBAC rules" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    echo
    echo "$ gcloud beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type e2-standard-2 --num-nodes 4 --spot --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE --project $GCP_PROJECT # to create cluster" | pv -qL 100
    gcloud beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type e2-standard-2 --num-nodes 4 --spot --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE --project $GCP_PROJECT
    echo      
    echo "$ gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT # to retrieve credentials for cluster" | pv -qL 100
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"$(gcloud config get-value core/account)\" # to enable user to set RBAC rules" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    echo
    echo "$ gcloud beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT # to delete cluster" | pv -qL 100
    gcloud beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT
else
    export STEP="${STEP},2i"   
    echo
    echo "1. Create container cluster" | pv -qL 100
    echo "2. Retrieve the credentials for cluster" | pv -qL 100
    echo "3. Enable current user to set RBAC rules" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"       
    echo
    echo "$ gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml \$PROJDIR/config-management-operator.yaml # to copy yaml" | pv -qL 100
    echo
    echo "$ kubectl apply -f \$PROJDIR/config-management-operator.yaml # to apply yaml" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml $PROJDIR/config-management-operator.yaml # to copy yaml" | pv -qL 100
    gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml $PROJDIR/config-management-operator.yaml
    echo
    echo "$ kubectl apply -f $PROJDIR/config-management-operator.yaml # to apply yaml" | pv -qL 100
    kubectl apply -f $PROJDIR/config-management-operator.yaml
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ kubectl delete -f $PROJDIR/config-management-operator.yaml # to delete yaml" | pv -qL 100
    kubectl delete -f $PROJDIR/config-management-operator.yaml
else
    export STEP="${STEP},3i"       
    echo
    echo "1. Apply config management operator" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"        
    echo
    echo "$ git clone https://github.com/GoogleCloudPlatform/csp-config-management.git /tmp/csp-config-management # to clone repo" | pv -qL 100
    echo
    echo "$ tree # to view content" | pv -qL 100
    echo
    echo "$ git config --global init.defaultBranch main # to set branch"
    echo
    echo "$ git init # to initialize git" | pv -qL 100
    echo
    echo "$ git add . # to add content to repo" | pv -qL 100
    echo
    echo "$ git commit -m \"Initial config repo commit\" # to commit changes to repo" | pv -qL 100
    echo
    echo "$ gcloud source repos create foo-corp # to create cloud source repository" | pv -qL 100
    echo
    echo "$ git remote add origin https://source.developers.google.com/p/\$GCP_PROJECT/r/foo-corp # add remote repo as origin" | pv -qL 100
    echo
    echo "$ git push origin main # to origin to repository main branch" | pv -qL 100
    echo
    echo "$ ssh-keygen -t rsa -b 4096 -C \"\$(gcloud config get-value account)\" -N '' -f \$PROJDIR/.ssh/id_rsa.acm # to generate an SSH keypair" | pv -qL 100
    echo
    echo "$ kubectl create secret generic git-creds --namespace=config-management-system --from-file=ssh=\$HOME/.ssh/id_rsa.acm # to create a Kubernetes Secret to store the private key" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT > /dev/null 2>&1 
    sudo apt-get install tree > /dev/null 2>&1 # to install tree"
    rm -rf /tmp/csp-config-management 
    echo
    echo "$ git clone https://github.com/GoogleCloudPlatform/csp-config-management.git /tmp/csp-config-management # to clone repo" | pv -qL 100
    git clone https://github.com/GoogleCloudPlatform/csp-config-management.git /tmp/csp-config-management
    echo
    echo "$ cp -rf /tmp/csp-config-management/foo-corp $PROJDIR # to copy configuration files" | pv -qL 100
    cp -rf /tmp/csp-config-management/foo-corp $PROJDIR
    echo
    git config --global user.email "$(gcloud config get-value account)" > /dev/null 2>&1
    git config --global user.name "USER" > /dev/null 2>&1
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ cd $PROJDIR/foo-corp # to change to project directory" | pv -qL 100
    cd $PROJDIR/foo-corp
    echo
    echo "$ tree # to view content" | pv -qL 100
    tree
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ git config --global init.defaultBranch main # to set branch"
    git config --global init.defaultBranch main
    echo
    echo "$ git init # to initialize git" | pv -qL 100
    git init
    echo
    echo "$ git add . # to add content to repo" | pv -qL 100
    git add .
    echo
    echo "$ git commit -m \"Initial config repo commit\" # to commit changes to repo" | pv -qL 100
    git commit -m "Initial config repo commit" 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ gcloud source repos create foo-corp # to create cloud source repository" | pv -qL 100
    gcloud source repos create foo-corp
    echo
    git config credential.helper gcloud.sh > /dev/null 2>&1 # to supply credentials for Git access
    echo "$ git remote add origin https://source.developers.google.com/p/$GCP_PROJECT/r/foo-corp # add remote repo as origin" | pv -qL 100
    git remote add origin https://source.developers.google.com/p/$GCP_PROJECT/r/foo-corp
    echo
    echo "$ git push origin main # to origin to repository main branch" | pv -qL 100
    git push origin main
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ ssh-keygen -t rsa -b 4096 -C \"$(gcloud config get-value account)\" -N '' -f $HOME/.ssh/id_rsa.acm # to generate an SSH keypair" | pv -qL 100
    ssh-keygen -t rsa -b 4096 -C "$(gcloud config get-value account)" -N '' -f $HOME/.ssh/id_rsa.acm
    echo
    echo "$ kubectl create secret generic git-creds --namespace=config-management-system --from-file=ssh=$HOME/.ssh/id_rsa.acm # to create a Kubernetes Secret to store the private key" | pv -qL 100
    kubectl create secret generic git-creds --namespace=config-management-system --from-file=ssh=$HOME/.ssh/id_rsa.acm
    echo
    echo "$ cat $HOME/.ssh/id_rsa.acm.pub # to display SSH key for registration in Cloud Source Repositories" | pv -qL 100
    cat $HOME/.ssh/id_rsa.acm.pub
    echo
    echo "*** Register SSH Key at https://source.cloud.google.com/user/ssh_keys?register=true ***"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ kubectl delete secret git-creds --namespace=config-management-system # to delete secret" | pv -qL 100
    kubectl delete secret git-creds --namespace=config-management-system
    echo
    echo "$ gcloud source repos delete foo-corp # to delete repository" | pv -qL 100
    gcloud source repos delete foo-corp
else
    export STEP="${STEP},4i"        
    echo
    echo " 1. Enable APIs" | pv -qL 100
    echo " 2. Clone repo" | pv -qL 100
    echo " 3. Copy configuration files" | pv -qL 100
    echo " 4. Set branch"
    echo " 5. Initialize git" | pv -qL 100
    echo " 6. Commit changes to repo" | pv -qL 100
    echo " 7. Create cloud source repository" | pv -qL 100
    echo " 8. Add remote repo as origin" | pv -qL 100
    echo " 9. Push origin to repository main branch" | pv -qL 100
    echo "10. Create a Kubernetes Secret to store the private key" | pv -qL 100
    echo "11. Display SSH key for registration in Cloud Source Repositories" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"        
    echo
    echo "$ kubectl apply -f - <<EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
  namespace: config-management-system
spec:
  clusterName: \$GCP_CLUSTER
  enableMultiRepo : true
  enableLegacyFields: true
  policyController:
    enabled: true
  hierarchyController:
    enabled: true
  git:
    syncRepo: ssh://\$(gcloud config get-value account)@source.developers.google.com:2022/p/\${GCP_PROJECT}/r/foo-corp
    syncBranch: main
    secretType: ssh
    policyDir: \".\"
    syncWait: 2
EOF" | pv -qL 100
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n config-management-system # to wait for the deployment to finish" | pv -qL 100
    echo
    echo "$ sudo apt-get install google-cloud-sdk-nomos # to install nomos"
    echo
    echo "$ /usr/bin/nomos status # to check status"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl apply -f - <<EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
  namespace: config-management-system
spec:
  clusterName: $GCP_CLUSTER
  enableMultiRepo : true
  enableLegacyFields: true
  policyController:
    enabled: true
  hierarchyController:
    enabled: true
  git:
    syncRepo: ssh://$(gcloud config get-value account)@source.developers.google.com:2022/p/${GCP_PROJECT}/r/foo-corp
    syncBranch: main
    secretType: ssh
    policyDir: \".\"
    syncWait: 2
EOF" | pv -qL 100
kubectl apply -f - <<EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
  namespace: config-management-system
spec:
  clusterName: $GCP_CLUSTER
  enableMultiRepo : true
  enableLegacyFields: true
  policyController:
    enabled: true
  hierarchyController:
    enabled: true
  git:
    syncRepo: ssh://$(gcloud config get-value account)@source.developers.google.com:2022/p/${GCP_PROJECT}/r/foo-corp
    syncBranch: main
    secretType: ssh
    policyDir: "."
    syncWait: 2
EOF
    echo
    echo "$ sleep 120 # to wait"
    sleep 120
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n config-management-system # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n config-management-system
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n gatekeeper-system # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n gatekeeper-system
    echo
    echo "$ sudo apt-get install google-cloud-sdk-nomos # to install nomos"
    sudo apt-get install google-cloud-sdk-nomos
    echo
    echo "$ /usr/bin/nomos status # to check status"
    /usr/bin/nomos status
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl -n config-management-system delete ConfigManagement config-management # to delete ConfigManagement" | pv -qL 100
    kubectl -n config-management-system delete ConfigManagement config-management
else
    export STEP="${STEP},5i"        
    echo
    echo "1. Apply config management configuration" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"   
    echo
    echo "$ kubectl describe ns shipping-dev # to describe namespace" | pv -qL 100
    echo
    echo "$ kubectl delete namespace shipping-dev # to delete namespace" | pv -qL 100
    echo
    echo "$ kubectl get ns shipping-dev # to confirm namespace recreation" | pv -qL 100
    echo
    echo "$ kubectl describe clusterrolebinding namespace-readers # to view config" | pv -qL 100
    echo
    echo "$ git add . # to add directory" | pv -qL 100
    echo
    echo "$ git commit -m \"Added user to namespace-reader\" # to commit change" | pv -qL 100
    echo
    echo "$ git push origin main # to push change to main" | pv -qL 100
    echo
    echo "$ kubectl describe ClusterRoleBinding namespace-readers # to view config" | pv -qL 100
    echo
    echo "$ git revert --no-edit HEAD # to revert change" | pv -qL 100
    echo
    echo "$ git push origin main # to push original config to main" | pv -qL 100
    echo
    echo "$ kubectl describe clusterrolebinding namespace-readers # to view config" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl describe ns shipping-dev # to describe namespace" | pv -qL 100
    kubectl describe ns shipping-dev
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl delete namespace shipping-dev # to delete namespace" | pv -qL 100
    kubectl delete namespace shipping-dev
    sleep 10
    echo
    echo "$ kubectl get ns shipping-dev # to confirm namespace recreation" | pv -qL 100
    kubectl get ns shipping-dev
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl describe clusterrolebinding namespace-readers # to view config" | pv -qL 100
    kubectl describe clusterrolebinding namespace-readers
    echo
    echo "*** Edit $PROJDIR/foo-corp/cluster/namespace-reader-clusterrolebinding.yaml to add subject ***" | pv -qL 100
    echo
    read -n 1 -s -r -p "$ "
    echo
    echo "$ cat $PROJDIR/foo-corp/cluster/namespace-reader-clusterrolebinding.yaml # to display edited config file" | pv -qL 100
    cat $PROJDIR/foo-corp/cluster/namespace-reader-clusterrolebinding.yaml
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo
    echo "$ cd $PROJDIR/foo-corp/ # to change directory" | pv -qL 100
    cd $PROJDIR/foo-corp/
    echo
    echo "$ git add . # to add directory" | pv -qL 100
    git add .
    echo
    echo "$ git commit -m \"Added user to namespace-reader\" # to commit change" | pv -qL 100
    git commit -m "Added user to namespace-reader"
    echo
    echo "$ git push origin main # to push change to main" | pv -qL 100
    git push origin main 
    echo
    echo "$ sleep 15 # to wait" | pv -qL 100
    sleep 15
    echo
    echo "$ kubectl describe ClusterRoleBinding namespace-readers # to view config" | pv -qL 100
    kubectl describe ClusterRoleBinding namespace-readers
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ git revert --no-edit HEAD # to revert change" | pv -qL 100
    git revert --no-edit HEAD
    echo
    echo "$ git push origin main # to push original config to main" | pv -qL 100
    git push origin main
    echo
    echo "$ sleep 10 # to wait" | pv -qL 100
    sleep 10
    echo
    echo "$ kubectl describe clusterrolebinding namespace-readers # to view config" | pv -qL 100
    kubectl describe clusterrolebinding namespace-readers
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"   
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},6i"   
    echo
    echo " 1. Enable APIs" | pv -qL 100
    echo " 2. Describe namespace" | pv -qL 100
    echo " 3. Delete namespace" | pv -qL 100
    echo " 4. Confirm namespace recreation" | pv -qL 100
    echo " 5. View config" | pv -qL 100
    echo " 6. Add directory" | pv -qL 100
    echo " 7. Commit change" | pv -qL 100
    echo " 8. Push change to main" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"        
    echo
    echo "$ kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-env
spec:
  match:
    kinds:
      - apiGroups: [\"\"]
        kinds: [\"Namespace\"]
  parameters:
    labels:
      - key: \"env\"
EOF" | pv -qL 100
    echo
    echo "$ kubectl describe ns shipping-prod # to describe namespace" | pv -qL 100
    echo
    echo "$ kubectl delete namespace shipping-prod # to delete namespace" | pv -qL 100
    echo
    echo "$ kubectl get ns shipping-prod # to confirm namespace recreation" | pv -qL 100
    echo
    echo "$ kubectl describe ns shipping-dev # to describe namespace" | pv -qL 100
    echo
    echo "$ kubectl delete namespace shipping-dev # to delete namespace" | pv -qL 100
    echo
    echo "$ kubectl get ns shipping-dev # to confirm namespace recreation" | pv -qL 100
    echo
    echo "$ git add . # to add directory with config updates" | pv -qL 100
    echo
    echo "$ git commit -m \"Added namespace with label\" # to commit change" | pv -qL 100
    echo
    echo "$ git push origin main # to push change to main" | pv -qL 100
    echo
    echo "$ kubectl describe ns shipping-dev # to view config" | pv -qL 100
    echo
    echo "$ kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-env
spec:
  enforcementAction: dryrun
  match:
    kinds:
      - apiGroups: [\"\"]
        kinds: [\"Namespace\"]
  parameters:
    labels:
      - key: \"env\"
EOF" | pv -qL 100    
        echo
        echo "$ kubectl apply -f - <<EOF
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sdenyname
spec:
  crd:
    spec:
      names:
        kind: K8sDenyName
      validation:
        openAPIV3Schema:
          properties:
            invalidName:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenynames
        violation[{\"msg\": msg}] {
          input.review.object.metadata.name == input.parameters.invalidName
          msg := sprintf(\"The name %v is not allowed\", [input.parameters.invalidName])
        }
EOF" | pv -qL 100
    echo
    echo "$ kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyName
metadata:
  name: no-policy-violation
spec:
  parameters:
    invalidName: \"policy-violation\"
EOF" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE --project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-env
spec:
  match:
    kinds:
      - apiGroups: [\"\"]
        kinds: [\"Namespace\"]
  parameters:
    labels:
      - key: \"env\"
EOF" | pv -qL 100
        kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-env
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels:
      - key: "env"
EOF
    echo
    echo "$ sleep 15 # to wait" | pv -qL 100
    sleep 15
    echo
    echo "$ kubectl describe ns shipping-prod # to describe namespace" | pv -qL 100
    kubectl describe ns shipping-prod
    sleep 10
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl delete namespace shipping-prod # to delete namespace" | pv -qL 100
    kubectl delete namespace shipping-prod
    sleep 10
    echo
    echo "$ kubectl get ns shipping-prod # to confirm namespace recreation" | pv -qL 100
    kubectl get ns shipping-prod 
    echo
    echo "$ kubectl describe ns shipping-dev # to describe namespace" | pv -qL 100
    kubectl describe ns shipping-dev
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl delete namespace shipping-dev # to delete namespace" | pv -qL 100
    kubectl delete namespace shipping-dev
    sleep 10
    echo
    echo "$ kubectl get ns shipping-dev # to confirm namespace recreation" | pv -qL 100
    kubectl get ns shipping-dev 
    echo
    echo "*** Edit $PROJDIR/foo-corp/namespaces/online/shipping-app-backend/shipping-dev/namespace.yaml to add label env: dev ***" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ cat $PROJDIR/foo-corp/namespaces/online/shipping-app-backend/shipping-dev/namespace.yaml # to display edited config file" | pv -qL 100
    cat $PROJDIR/foo-corp/namespaces/online/shipping-app-backend/shipping-dev/namespace.yaml
    echo && echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ cd $PROJDIR/foo-corp/ # to change directory" | pv -qL 100
    cd $PROJDIR/foo-corp/
    echo
    echo "$ git add . # to add directory" | pv -qL 100
    git add .
    echo
    echo "$ git commit -m \"Added namespace with label\" # to commit change" | pv -qL 100
    git commit -m "Added namespace with label"
    echo
    echo "$ git push origin main # to push change to main" | pv -qL 100
    git push origin main
    echo
    echo "$ sleep 15 # to wait" | pv -qL 100
    sleep 15
    echo
    echo "$ kubectl describe ns shipping-dev # to view config" | pv -qL 100
    kubectl describe ns shipping-dev
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-env
spec:
  enforcementAction: dryrun
  match:
    kinds:
      - apiGroups: [\"\"]
        kinds: [\"Namespace\"]
  parameters:
    labels:
      - key: \"env\"
EOF" | pv -qL 100    
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -f - <<EOF
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sdenyname
spec:
  crd:
    spec:
      names:
        kind: K8sDenyName
      validation:
        openAPIV3Schema:
          properties:
            invalidName:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenynames
        violation[{\"msg\": msg}] {
          input.review.object.metadata.name == input.parameters.invalidName
          msg := sprintf(\"The name %v is not allowed\", [input.parameters.invalidName])
        }
EOF" | pv -qL 100
    kubectl apply -f - <<EOF
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sdenyname
spec:
  crd:
    spec:
      names:
        kind: K8sDenyName
      validation:
        openAPIV3Schema:
          properties:
            invalidName:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenynames
        violation[{"msg": msg}] {
          input.review.object.metadata.name == input.parameters.invalidName
          msg := sprintf("The name %v is not allowed", [input.parameters.invalidName])
        }
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyName
metadata:
  name: no-policy-violation
spec:
  parameters:
    invalidName: \"policy-violation\"
EOF" | pv -qL 100
        kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyName
metadata:
  name: no-policy-violation
spec:
  parameters:
    invalidName: "policy-violation"
EOF
    sleep 15
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl create namespace policy-violation # to create disallowed namespace" | pv -qL 100
    kubectl create namespace policy-violation
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl delete K8sRequiredLabels ns-must-have-env # to delete constaint" | pv -qL 100
    kubectl delete K8sRequiredLabels ns-must-have-env
    echo
    echo "$ kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io gatekeeper-validating-webhook-configuration # to re-enable Policy Controller" | pv -qL 100
    kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io gatekeeper-validating-webhook-configuration
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"   
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},7i"        
    echo
    echo " 1. Enable APIs" | pv -qL 100
    echo " 2. Apply gatekeeper constraints" | pv -qL 100
    echo " 3. Describe namespace" | pv -qL 100
    echo " 4. Delete namespace" | pv -qL 100
    echo " 5. Confirm namespace recreation" | pv -qL 100
    echo " 6. Describe namespace" | pv -qL 100
    echo " 7. Delete namespace" | pv -qL 100
    echo " 8. Confirm namespace recreation" | pv -qL 100
    echo " 9. Add label env: dev ***" | pv -qL 100
    echo "10. Display edited config file" | pv -qL 100
    echo "11. Add directory" | pv -qL 100
    echo "12. Commit change" | pv -qL 100
    echo "13. Push change to main" | pv -qL 100
    echo "14. View config" | pv -qL 100
    echo "15. Apply custom gatekeeper namespace constraints" | pv -qL 100
    echo "16. Create disallowed namespace" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done

