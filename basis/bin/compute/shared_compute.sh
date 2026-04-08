if [ -f $HOME/compute/tf_env.sh ]; then
    . $HOME/compute/tf_env.sh
    export IS_BASTION="true"
fi

# -- Shared Compute Functions ------------------------------------------------

title() {
  line='-------------------------------------------------------------------------'
  NAME=$1
  echo
  echo "-- $NAME ${line:${#NAME}}"
  echo  
}
export -f title

# The apps are installed in alphabetical order
app_dir_list() {
  ls -d app app/* 2>/dev/null | sort -g
}
export -f app_dir_list

install_java() {
  # Install the JVM (jdk or graalvm)
  if [ "$TF_VAR_java_vm" != "jdk" ]; then
    if grep -q 'export JAVA_HOME' $HOME/.bashrc; then
      echo "Java already installed " 
      return
    fi
    # GraalVM
    if [ "$TF_VAR_java_version" == 8 ]; then
      sudo dnf install -y graalvm21-ee-8-jdk 
      export JAVA_HOME=/usr/lib64/graalvm/graalvm22-ee-java8
    elif [ "$TF_VAR_java_version" == 11 ]; then
      sudo dnf install -y graalvm22-ee-11-jdk
      export JAVA_HOME=/usr/lib64/graalvm/graalvm22-ee-java11
    elif [ "$TF_VAR_java_version" == 17 ]; then
      sudo dnf install -y graalvm22-ee-17-jdk 
      export JAVA_HOME=/usr/lib64/graalvm/graalvm22-ee-java17
    elif [ "$TF_VAR_java_version" == 21 ]; then
      sudo dnf install -y graalvm-21-jdk
      export JAVA_HOME=/usr/lib64/graalvm/graalvm-java21
    else
      sudo dnf install -y graalvm-25-jdk
      export JAVA_HOME=/usr/lib64/graalvm/graalvm-java25    
      # sudo update-alternatives --set native-image $JAVA_HOME/lib/svm/bin/native-image
    fi   
    sudo update-alternatives --set java $JAVA_HOME/bin/java
    echo "export JAVA_HOME=${JAVA_HOME}" >> $HOME/.bashrc
  else
    # JDK 
    # Needed due to concurrency
    sudo dnf install -y alsa-lib 
    if [ "$TF_VAR_java_version" == 8 ]; then
      sudo dnf install -y java-1.8.0-openjdk
    elif [ "$TF_VAR_java_version" == 11 ]; then
      sudo dnf install -y java-11  
    elif [ "$TF_VAR_java_version" == 17 ]; then
      sudo dnf install -y java-17        
    elif [ "$TF_VAR_java_version" == 21 ]; then
      sudo dnf install -y java-21         
    else
      sudo dnf install -y java-25  
      # Trick to find the path
      # cd -P "/usr/java/latest"
      # export JAVA_LATEST_PATH=`pwd`
      # cd -
      # sudo update-alternatives --set java $JAVA_LATEST_PATH/bin/java
    fi
  fi

  # JMS agent deploy (to fleet_ocid )
  if [ -f jms_agent_deploy.sh ]; then
    chmod +x jms_agent_deploy.sh
    sudo ./jms_agent_deploy.sh
  fi
}
export -f install_java

# Install tnsnames.ora
install_tnsname() {
    # Run SQLCl
    # Install the tables
    export TNS_ADMIN=$HOME/app/db
    mkdir -p $TNS_ADMIN
    cat > $TNS_ADMIN/tnsnames.ora <<EOT
DB = $DB_URL
EOT
}
export -f install_tnsname

# Download
function download()
{
   echo "Downloading - $1"
   wget -nv $1
}
export -f download

# Install SQLCL 
install_sqlcl() {
    install_java
    install_tnsname
    cd $HOME/db
    if [ ! -f sqlcl-latest.zip ]; then
        download https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip
        rm -Rf sqlcl
        unzip sqlcl-latest.zip
    fi 
    cd -
}  
export -f install_sqlcl

# Install Python
install_python() {
    sudo dnf install -y python3.12 python3.12-pip python3-devel wget
    sudo update-alternatives --set python /usr/bin/python3.12
    curl -LsSf https://astral.sh/uv/install.sh | sh
    uv venv myenv
    source myenv/bin/activate
    if [ -f requirements.txt ]; then 
      uv pip install -r requirements.txt
    fi 
    if [ -f src/requirements.txt ]; then 
      uv pip install -r src/requirements.txt
    fi 
}
export -f install_python

# Install LibreOffice
install_libreoffice() {
    export STABLE_VERSIONS=`curl -s https://download.documentfoundation.org/libreoffice/stable/`
    export LIBREOFFICE_VERSION=`echo $STABLE_VERSIONS | sed 's/.*<td valign="top">//' | sed 's/\/<\/a>.*//' | sed 's/.*\/">//'`
    echo LIBREOFFICE_VERSION=$LIBREOFFICE_VERSION
    cd /tmp
    export LIBREOFFICE_TGZ="LibreOffice_${LIBREOFFICE_VERSION}_Linux_x86-64_rpm.tar.gz"
    if [ ! -f $LIBREOFFICE_TGZ ]; then
        sudo dnf group install -y "Server with GUI"

        download https://download.documentfoundation.org/libreoffice/stable/${LIBREOFFICE_VERSION}/rpm/x86_64/$LIBREOFFICE_TGZ
        tar -xzvf $LIBREOFFICE_TGZ
        cd LibreOffice*/RPMS
        sudo dnf install *.rpm -y
    fi 
    export LIBRE_OFFICE_EXE=`find ${PATH//:/ } -maxdepth 1 -executable -name 'libreoffice*' | grep "libreoffice"`
    echo LIBRE_OFFICE_EXE=$LIBRE_OFFICE_EXE
    cd -
} 
export -f install_libreoffice   

# Install Chrome
install_chrome() {
    cd /tmp
    export CHROME_RPM="google-chrome-stable_current_x86_64.rpm"
    if [ ! -f $CHROME_RPM ]; then
      cd /tmp
      download https://dl.google.com/linux/direct/$CHROME_RPM
      sudo dnf localinstall -y $CHROME_RPM
    fi
    cd -
} 
export -f install_chrome   

# Install InstantClient (including SqlPlus)
install_instant_client() {
    install_tnsname

    # Install SQL*InstantClient
    if [[ `arch` == "aarch64" ]]; then
        sudo dnf install -y oracle-release-el8 
        sudo dnf install -y oracle-instantclient19.19-basic oracle-instantclient19.19-sqlplus oracle-instantclient19.19-tools
    else
        export INSTANT_VERSION=23.26.0.0.0-1
        cd /tmp
        if [ ! -f /tmp/oracle-instantclient-basic-${INSTANT_VERSION}.el8.x86_64.rpm ]; then
            wget -nv https://download.oracle.com/otn_software/linux/instantclient/2326000/oracle-instantclient-basic-${INSTANT_VERSION}.el8.x86_64.rpm
            wget -nv https://download.oracle.com/otn_software/linux/instantclient/2326000/oracle-instantclient-sqlplus-${INSTANT_VERSION}.el8.x86_64.rpm
            wget -nv https://download.oracle.com/otn_software/linux/instantclient/2326000/oracle-instantclient-tools-${INSTANT_VERSION}.el8.x86_64.rpm
            sudo dnf install -y oracle-instantclient-basic-${INSTANT_VERSION}.el8.x86_64.rpm oracle-instantclient-sqlplus-${INSTANT_VERSION}.el8.x86_64.rpm oracle-instantclient-tools-${INSTANT_VERSION}.el8.x86_64.rpm
        fi 
        cd -
    fi
}
export -f install_instant_client   

create_self_signed_ip_certificate()
{
    mkdir -p certificate
    cd certificate
    # IP Certificate Request      
    cat > san.cnf << EOF     
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = US
ST = State
L = City
O = Organization
CN = $BASTION_IP

[req_ext]
subjectAltName = @alt_names

[alt_names]
IP.1 = $BASTION_IP
EOF

    # Generate the key and the chain      
    openssl genrsa -out server.key 2048
    openssl req -new -key server.key -out server.csr -config san.cnf
    openssl x509 -req -in server.csr -signkey server.key -out server.crt -days 365 -extensions req_ext -extfile san.cnf
    cd -

    cat > nginx_tls.conf << EOF     
# Self Signed IP Certificate     
server {
    server_name  $BASTION_IP; 
    root         /usr/share/nginx/html;

    # Load configuration files for the default server block.
    include /etc/nginx/default.d/*.conf;
    location / {
    }

    include conf.d/nginx_app.locations;
    error_page 404 /404.html;
        location = /40x.html {
    }

    error_page 500 502 503 504 /50x.html;
        location = /50x.html {
    }
    listen [::]:443 ssl ipv6only=on; 
    listen 443 ssl; 
    ssl_certificate /home/opc/app/ui/certificate/server.crt; 
    ssl_certificate_key /home/opc/app/ui/certificate/server.key; 

    ssl_session_cache shared:le_nginx_SSL:10m;
    ssl_session_timeout 1440m;
    ssl_session_tickets off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
}
EOF
}
export -f create_self_signed_ip_certificate 


# -- Install NGINX  ------------------------------------------------------------------
install_ngnix() {
    title "NGINX"
    sudo dnf install nginx -y > /tmp/dnf_nginx.log

    # Default: location /app/ { proxy_pass http://localhost:8080 }
    if [ -f nginx_app.locations ]; then
        sudo cp nginx_app.locations /etc/nginx/conf.d/.
        if grep -q nginx_app /etc/nginx/nginx.conf; then
            echo "Include nginx_app.locations is already there"
        else
            echo "Adding nginx_app.locations"
            sudo awk -i inplace '/404.html/ && !x {print "        include conf.d/nginx_app.locations;"; x=1} 1' /etc/nginx/nginx.conf
        fi
    fi

    # TLS
    if [ ! -f nginx_tls.conf ]; then
        create_self_signed_ip_certificate  
    fi

    echo "Adding nginx_tls.conf"
    sudo cp nginx_tls.conf /etc/nginx/conf.d/.
    sudo awk -i inplace '/# HTTPS server/ && !x {print "        include conf.d/nginx_tls.conf;"; x=1} 1' /etc/nginx/nginx.conf

    # SE Linux (for proxy_pass)
    sudo setsebool -P httpd_can_network_connect 1

    # Start it
    sudo systemctl enable nginx
    sudo systemctl restart nginx

    if [ -d html ]; then
        # Copy the index file after the installation of nginx
        sudo cp -r html/* /usr/share/nginx/html/
    fi

    # Firewalld
    sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
    sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
    sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
    sudo firewall-cmd --reload

    # -- Util -------------------------------------------------------------------
    sudo dnf install -y psmisc
}
export -f install_ngnix 

# -- Install Docker tools ---------------------------------------------------

install_docker_tools() {
    # docker 
    sudo yum install -y docker
    # oci cli
    sudo dnf install -y git python36-oci-cli
    oci setup repair-file-permissions --file $HOME/.oci/config
    oci setup repair-file-permissions --file $HOME/.oci/oci_api_key.pem    
    echo "export OCI_CLI_AUTH=instance_principal" >> ~/.bashrc  

    # kubectl
    mkdir -p $HOME/bin
    cd $HOME/bin
    if [ `arch` == "x86_64" ]; then
        ARCH_PREFIX=amd64
    else
        ARCH_PREFIX=arm64
    fi
    curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH_PREFIX}/kubectl
    chmod +x kubectl
    echo "source <(kubectl completion bash)" >> ~/.bashrc
}

# -- file_replace_variables -------------------------------------------------
# Function to replace ##VARIABLE_NAME## in a file
# Replace ##OPTIONAL/VARIABLE_NAME## by variables if it exists or __NOT_USED__

file_replace_variables() {
  local file="$1"
  local temp_file=$(mktemp)

  echo "Replace variables in file: $1"
  while IFS= read -r line || [ -n "$line" ]; do  
    while [[ $line =~ (.*)##(.*)##(.*) ]]; do
      local var_name="${BASH_REMATCH[2]}"
      echo "- variable: ${var_name}"

      if [[ ${var_name} =~ OPTIONAL/(.*) ]]; then
         var_name2="${BASH_REMATCH[1]}"
         var_value="${!var_name2}"
         if [ "$var_value" == "" ]; then
            var_value="__NOT_USED__"
         fi
      else
        var_value="${!var_name}"       
        if [ "$var_value" == "" ]; then
            echo "ERROR: Environment variable '${var_name}' is not defined."
            error_exit
        fi
      fi
      line=${line/"##${var_name}##"/${var_value}}
    done

    echo "$line" >> "$temp_file"
  done < "$file"

  mv "$temp_file" "$file"
}
export -f file_replace_variables 

# -- Apply k8s file after replacing the variables ---------------------------
copy_replace_apply_target_oke() {
  filepath="$1"  
  filename="${filepath##*/}"
  echo "-- kubectl apply -- $filename --"
  cp $filepath $TARGET_OKE/${filename}
  file_replace_variables $TARGET_OKE/${filename}
  kubectl apply -f $TARGET_OKE/${filename}
}
export -f copy_replace_apply_target_oke 

# -- build_ui ------------------------------------------------------------------
build_ui() {
    cd $SCRIPT_DIR/ui
    if is_deploy_compute; then
        if [ "$IS_BASTION" != "" ]; then
            ./install.sh
        else 
            mkdir -p $TARGET_DIR/compute/app/ui/html
            cp -r html/* $TARGET_DIR/compute/app/ui/html/.
            cp nginx* $TARGET_DIR/compute/app/ui/.
            cp install.sh $TARGET_DIR/compute/app/ui/.
        fi
    elif [ "$TF_VAR_deploy_type" == "function" ]; then 
        oci os object bulk-upload -ns $TF_VAR_namespace -bn ${TF_VAR_prefix}-public-bucket --src-dir html --overwrite --content-type auto
    else
        # Kubernetes and Container Instances
        docker image rm ${TF_VAR_prefix}-ui:latest
        docker build -t ${TF_VAR_prefix}-ui:latest .
    fi 
}
export -f build_ui 

# -- java_build_common ------------------------------------------------------
java_build_common() {
    if [ "${OCI_CLI_CLOUD_SHELL,,}" == "true" ]; then
        # csruntimectl is a function defined in /etc/bashrc.cloudshell
        . /etc/bashrc.cloudshell
        export JAVA_ID=`csruntimectl java list | grep jdk-17 | sed -e 's/^.*\(graal[^ ]*\) .*$/\1/'`
        csruntimectl java set $JAVA_ID
    fi

    if [ -f $TARGET_DIR/jms_agent_deploy.sh ]; then
        cp $TARGET_DIR/jms_agent_deploy.sh $TARGET_DIR/compute/.
    fi

    if [ -f $PROJECT_DIR/../group_common/target/jms_agent_deploy.sh ]; then
        cp $PROJECT_DIR/../group_common/target/jms_agent_deploy.sh $TARGET_DIR/compute/.
    fi
}
export -f java_build_common 

# -- build_rsync ------------------------------------------------------------
build_rsync() {
    if [ "$IS_BASTION" != "" ]; then
        return
    fi

    if [ "$1" == "" ]; then
        error_exit "Missing src parameter"
    fi

    # In Java, copy the src/*.sh to target 
    if [ -d target ]; then
        cp src/*.sh target/.
    fi

    # Copy all the app files in $TARGET_DIR/compute/$APP_NAME
    mkdir -p $TARGET_DIR/compute/$APP_COMPUTE_DIR
    rsync -av --progress $1/ $TARGET_DIR/compute/$APP_COMPUTE_DIR --exclude starter --exclude terraform.tfvars

    # Replace the user and password in start.sh
    if [ -f $TARGET_DIR/compute/$APP_COMPUTE_DIR/start.sh ]; then
        replace_db_user_password_in_file $TARGET_DIR/compute/$APP_COMPUTE_DIR/start.sh
    fi

    # Replace variables in env.sh
    if [ -f $TARGET_DIR/compute/$APP_COMPUTE_DIR/env.sh ]; then 
        file_replace_variables $TARGET_DIR/compute/$APP_COMPUTE_DIR/env.sh
    fi 
}

# -- docker_login -----------------------------------------------------------
docker_login() {
    oci raw-request --region $TF_VAR_region --http-method GET --target-uri "https://${OCIR_HOST}/20180419/docker/token" | jq -r .data.token | docker login -u BEARER_TOKEN --password-stdin ${OCIR_HOST}
    exit_on_error "Docker Login"
}