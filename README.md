# Poste.io

镜像构建所用到的配置文件来自 [dirtsimple](https://github.com/dirtsimple/poste.io) 


## Install Poste.io

使用`caddy`反代 不管是 `Bridge` 还是 `Host` 可以禁用 https 

```
- HTTPS=OFF
```



### DNS Records

| Type  |          Name           |                        Content                        |
| :---: | :---------------------: | :---------------------------------------------------: |
|   A   |          mail           |                      IPv4 Adress                      |
| AAAA  |          mail           |                      IPv6 Adress                      |
| CNAME |          imap           |                         mail                          |
| CNAME |           pop           |                         mail                          |
| CNAME |          smtp           |                         mail                          |
|  MX   |       domain.com        |                    mail.domain.com                    |
|  TXT  |         _dmarc          | v=DMARC1; p=none; pct=100; rua=mailto:mail@domain.com |
|  TXT  | s20231006555._domainkey |             k=rsa; p=(由Poste.io后台生成)             |
|  TXT  |       domain.com        |                    v=spf1 mx ~all                     |

如果可以的话 给你的 IP Adress 配置 rDNS 解析ip到 `mail.domain.com` 



### Caddy

**Caddyfile**

```ini
mail.domain.com imap.domain.com smtp.domain.com pop.domain.com {
    reverse_proxy 127.0.0.1:8808 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up Upgrade {http.upgrade}
        header_up Connection {http.upgrade}
        header_down Location http://mail.domain.com:8808/(.*) https://mail.domain.com/$1
        transport http {
            read_buffer 8192
        }
    }

    header Strict-Transport-Security "max-age=31536000; includeSubDomains;"

}
```



## Bridge

**docker compose** 

```yaml
services:
  Poste.io:
    image: analogic/poste.io
    container_name: poste
    hostname: mail.domain.com
    restart: always
    ports:
      - "25:25"
      - "110:110"
      - "143:143"
      - "587:587"
      - "993:993"
      - "995:995"
      - "4190:4190"
      - "465:465"
      - "127.0.0.1:8808:80"
    environment:
      - LETSENCRYPT_EMAIL=admin@domain.com
      - LETSENCRYPT_HOST=mail.domain.com
      - VIRTUAL_HOST=mail.domain.com
      - TZ=Asia/Shanghai
      - HTTPS=OFF
      - DISABLE_CLAMAV=TRUE #禁用反病毒 如果内存小于2G建议开启 非常占内存
    volumes:
      - './data:/data'
      - '/etc/localtime:/etc/localtime:ro'
    networks:
      - Poste.io
      
networks:
  Poste.io:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: "Poste_io"
    ipam:
      config:
        - subnet: 172.20.0.0/24
          gateway: 172.20.0.1
```



## Host 模式

为避免端口冲突 尽量一台服务器仅运行一个容器

**docker compose** 

```yaml
services:
  Poste.io:
    image: analogic/poste.io:latest
    container_name: poste
    hostname: mail.domain.com
    restart: always
    network_mode: host
    environment:
      - LETSENCRYPT_EMAIL=admin@domain.com
      - LETSENCRYPT_HOST=mail.domain.com
      - VIRTUAL_HOST=mail.domain.com
      - TZ=Asia/Shanghai
      - HTTPS=OFF
      - HTTP_PORT=8808 #随意修改
      - DISABLE_CLAMAV=TRUE #禁用反病毒 如果内存小于2G建议开启 非常占内存
    volumes:
      - './data:/data'
      - '/etc/localtime:/etc/localtime:ro'
```



## 修改内部程序配置

### Nginx

最终生效的配置会以 `https` `no-https` 这两个文件为模板生成

```bash
/etc/nginx/sites-enabled.templates/no-https
/etc/nginx/sites-enabled.templates/https

docker cp 'poste:/etc/nginx/sites-enabled.templates/no-https' ./
docker cp 'poste:/etc/nginx/sites-enabled.templates/https' ./
```

将从容器内复制的配置修改后映射到容器内

```yaml
volumes:
  - './https:/etc/nginx/sites-enabled.templates/https'
  - './no-https:/etc/nginx/sites-enabled.templates/no-https'
```



### PHP

`PHP` 的配置将会影响 `Poste.io` 的 `WebMail` 

```bash
/etc/php/7.4/fpm/pool.d/www.conf
/etc/php/7.4/fpm/pool.d/admin.conf

docker cp '/etc/php/7.4/fpm/pool.d/www.conf' ./
docker cp '/etc/php/7.4/fpm/pool.d/admin.conf' ./
```

将从容器内复制的配置修改后映射到容器内

```ini
[upload_max_filesize]=130M
[post_max_size]=130M
[memory_limit]=400M
[max_execution_time]=150
```

```yaml
volumes:
  - './www.conf:/etc/php/7.4/fpm/pool.d/www.conf'
  - './admin.conf:/etc/php/7.4/fpm/pool.d/admin.conf'
```



### WebMail

`WebMail` 中上传文件均受到 `PHP` 配置限制

`WebMail` 发邮件时,邮件的附件大小再受到 `PHP` 配置限制的同时,也会受到 `RoundCube` 的配置文件限制



### RoundCube

 `RoundCube` 的配置文件对邮件中附件的大小限制为 `max_message_size`的值 /1.33

```bash
/opt/www/webmail/config/defaults.inc.php

docker cp '/opt/www/webmail/config/defaults.inc.php' ./
```

将从容器内复制的配置修改后映射到容器内

```php
$config['max_message_size'] = '100M';
```

```yaml
volumes:
  - './defaults.inc.php:/opt/www/webmail/config/defaults.inc.php'
```


## Docker Build

```bash
git clone https://github.com/RexLee0929/Poste.io.git
cd Poste.io
docker build --build-arg UPSTREAM=2.4.7 -t name/poste.io:2.4.7 -t name/poste.io:latest .
```

构建完成后推送到 `Docker Hub`

```bash
docker push name/poste.io:2.4.7
docker push name/poste.io:latest
```


**docker compose**

```bash
services:
  Poste.io:
    image: name/poste.io:latest
    container_name: poste
    hostname: mail.domain.com
    restart: always
    network_mode: host
    environment:
      - LETSENCRYPT_EMAIL=admin@domain.com
      - LETSENCRYPT_HOST=mail.domain.com
      - VIRTUAL_HOST=mail.domain.com
      - TZ=Asia/Shanghai
      - HTTPS=OFF
      - HTTP_PORT=8808
      - DISABLE_CLAMAV=TRUE
      - LISTEN_ON=IPv4 IPv6
      - SEND_ON=IPv4
    volumes:
      - './data:/data'
      - '/etc/localtime:/etc/localtime:ro'
```

