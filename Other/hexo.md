## 阿里云ECS

### git

安装git

```
yum install git
```

**准备git仓库，存放hexo的源信息**

```
mkdir /home/git/
chown -R $USER:$USER /home/git/
chmod -R 755 /home/git/
cd /home/git/
git init --bare hexoBlog.git
```

**创建git hooks，方便自动部署**

/home/git/hexoBlog.git目录下，找到hooks子目录，新建文件post-receive

```
cd /home/git/hexoBlog.git/hooks
touch post-receive
```
文件内容修改如下

```
#!/bin/bash
git --work-tree=/home/hexoBlog --git-dir=/home/git/hexoBlog.git checkout -f
chmod +x /home/git/hexoBlog.git/hooks/post-receive
```

### Nginx

安装

```
yum install -y nginx
```

启动

```
service nginx start
```

创建托管目录

```
mkdir /home/hexoBlog/
chown -R $USER:$USER /home/hexoBlog/
chmod -R 755 /home/hexoBlog/
```

修改配置文件

```
vim /etc/nginx/nginx.conf
```

内容如下

```
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /home/hexoBlog;    #需要修改

    server_name evenyao.com; #博主的域名，需要修改成对应的域名

    # Load configuration files for the default server block.
    include /etc/nginx/default.d/*.conf;
    location / {
    }
    error_page 404 /404.html;
        location = /40x.html {
    }
```

重启

```
service nginx restart
```

## 本机

安装部署插件

```
npm install hexo-deployer-git --save
```

修改`_config.yml`，修改文件最后的depoly信息

```
deploy:
  type: git
  repo: root@xx.xx.xx.xx:/home/git/hexoBlog  //xx.xx.xx.xx为服务器地址
  branch: master
```

hexo下，部署执行

```
cd 你的hexo目录
hexo clean
hexo generate
hexo deploy
```

添加私钥

```
ssh-keygen
ssh-copy-id -i ~/.ssh/id_rsa.pub root@116.62.207.24
```

## 配置HTTPS

### ECS开放443端口

进入**ECS列表**，选择实例最后的**更多**，依次选择**网络安全组**，**安全组配置**，进入新的界面后，点**配置规则**。

添加安全组规则，端口范围：443/443，授权对象：0.0.0.0/0。

### 申请证书

阿里云控制台首页 -> SSL证书管理 -> 购买证书 -> 免费版个人

### 部署证书

证书列表页 -> 下载 -> Nginx

scp拷贝证书到ECS服务器

在`/etc/nginx`目录下新建`cert`目录，将刚刚的证书文件(.pem和.key)拷贝到cert目录。

修改`/etc/nginx/nginx.conf`的HTTSP部分，注意去掉注释

```
   server {
        listen       443 ssl http2 default_server;
        listen       [::]:443 ssl http2 default_server;
        server_name  _;
        root         /home/hexoBlog;

        ssl_certificate "cert/xxxx.com.pem";
        ssl_certificate_key "cert/xxxx.com.key";
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout  10m;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    }

}
```

