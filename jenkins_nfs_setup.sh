

mkdir /mnt/nfs
# mount -t nfs nas03:/volume1/multimedia /mnt/nfs




rpcinfo -s localhost




1) setup nfs server
vagrant
2) setup nfs mounts
vagrant
3) JENKINS POD : mount dirs

mkdir /mnt/nfs
mount -t nfs 192.168.7.11:/home/public /mnt/nfs
chmod -R 777 /mnt/nfs
mkdir -p /mnt/nfs/var/jenkins/home
mkdir -p /mnt/nfs/var/jenkins/restore


4) JENKINS PV CLAIM. MOUNT NFS AS PV&PVC


---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-volume-nfs 
spec:
  capacity:
    storage: 10Gi 
  accessModes:
  - ReadWriteOnce 
  nfs: 
    path: /home/public
    server: 192.168.7.11 
  persistentVolumeReclaimPolicy: Retain 

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-volume-nfs
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: "/home/public"
    server: "192.168.7.11"
    readOnly: false
-----------------------------------------
kind: Pod
apiVersion: v1
metadata:
  name: pod-using-nfs
spec:
  # Add the server as an NFS volume for the pod
  volumes:
    - name: nfs-volume
      nfs: 
        # URL for the NFS server
        server: 10.108.211.244 # Change this!
        path: /

  # In this container, we'll mount the NFS volume
  # and write the date to a file inside it.
  containers:
    - name: app
      image: alpine

      # Mount the NFS volume in the container
      volumeMounts:
        - name: nfs-volume
          mountPath: /var/nfs

      # Write to a file inside our NFS
      command: ["/bin/sh"]
      args: ["-c", "while true; do date >> /var/nfs/dates.txt; sleep 5; done"]

--------------------------------------------
mount -t nfs 10.30.136.79:/data/u4 /mnt
mount -t nfs -vvv 192.168.7.11:/home/public /mnt

mount -t nfs -vvv 192.168.7.11:/ /private/mnt/nfs

sudo mkdir -p /private/mnt/nfs
sudo chmod -R 777 /private/mnt/nfs
sudo mount -t nfs -o resvport,rw 192.168.7.11:/home/public/var /private/mnt/nfs
sudo mount -t nfs -o resvport,rw 192.168.7.11:/ /private/mnt/nfs

~/uga/data/backup/jenkins/

ls /Volumes/uga/data/backup/jenkins/backup_20210813_0618.zip

/--- ok ---/
scp -rp /Volumes/uga/data/backup/jenkins/backup_20210813_0618.zip vagrant@192.168.7.11:/home/public/


rpcinfo -p 192.168.7.11

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-volume-nfs
  namespace: jenkins
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins-admin-sa
      containers:
        - name: jenkins
          image: jenkins/jenkins:lts
        ports:
          - name: http-port
            containerPort: 8080
          - name: jnlp-port
            containerPort: 50000
        volumeMounts:
          - name: jenkins-persistent-storage
          mountPath: /var/jenkins_home
      volumes:
        - name: jenkins-persistent-storage
          persistentVolumeClaim:
          claimName: pv-volume-nfs


---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins-admin-sa
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
          - name: http-port
            containerPort: 8080
          - name: jnlp-port
            containerPort: 50000
        volumeMounts:
        - name: jenkins-persistent-storage
          mountPath: /var/jenkins_vol
      volumes:
      - name: jenkins-persistent-storage
        persistentVolumeClaim:
          claimName: pv-volume-jenkins

kcr8jenkins(){
  
  # cd ${JENKINS_HOME_LOCAL_USER}
  # rm -rf jenkins-kubernetes-pod
  # git clone https://github.com/karlring-devops/jenkins-kubernetes-pod.git
  
  # cd ${JENKINS_HOME_LOCAL_USER}/jenkins-kubernetes-pod/
  # #/---- REMOVED FILES in GIT NOW ------//# . ./setup_jenkins_kubernetes.sh
  
kubectl create -f jenkins-namespace.yaml
kubectl apply -f jenkins-role.yaml
kubectl apply -f jenkins-role-bind.yaml
kubectl create serviceaccount jenkins-admin-sa -n jenkins
kubectl create clusterrolebinding jenkins-admin-sa --clusterrole=cluster-admin --serviceaccount=jenkins:jenkins-admin-sa -n jenkins

kubectl create -f create-pv-jenkins.yaml
kubectl create -f create-pv-claim-jenkins.yaml
kubectl create -f jenkins-deployment.yaml
kubectl create -f jenkins-service.yaml --validate=false
kubectl create -f jenkins-service-jnlp.yaml
kubectl scale -n jenkins deployment jenkins --replicas=1
}


kdeljenkins(){
  kubectl delete namespace jenkins
  kubectl delete persistentvolume pv-volume-nfs -n jenkins
  kubectl delete persistentvolumeclaim pv-volume-nfs -n jenkins
  kubectl delete clusterrolebinding jenkins-admin-sa
}


vagrant@kmaster1:~/.jenkins/jenkins-kubernetes-pod$ cat create-pv-jenkins.yaml 
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-volume-jenkins
  namespace: jenkins
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"

vagrant@kmaster1:~/.jenkins/jenkins-kubernetes-pod$ cat create-pv-claim-jenkins.yaml 
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-volume-jenkins
  namespace: jenkins
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi


vagrant@kmaster1:~/.jenkins/jenkins-kubernetes-pod$ cat jenkins-deployment.yaml 
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins-admin-sa
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
          - name: http-port
            containerPort: 8080
          - name: jnlp-port
            containerPort: 50000
        volumeMounts:
        - name: jenkins-persistent-storage
          mountPath: /var/jenkins_vol
      volumes:
      - name: jenkins-persistent-storage
        persistentVolumeClaim:
          claimName: pv-volume-jenkins


---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins-admin-sa
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
          - name: http-port
            containerPort: 8080
          - name: jnlp-port
            containerPort: 50000
        volumeMounts:
        - name: jenkins-persistent-storage
          mountPath: /var/jenkins_home
      volumes:
      - name: jenkins-persistent-storage
        persistentVolumeClaim:
          claimName: pv-volume-jenkins


