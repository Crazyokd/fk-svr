# 新月杀5.4私服搭建
```拉取所有扩展
git submodule update --init --checkout
```
# 使用容器运行

1. 以ubuntu22.04作为基础镜像
```shell
docker run --net host --name fk-svr -w /work -e http_proxy=http://127.0.0.1:7890 -e https_proxy=http://127.0.0.1:7890 -e all_proxy=http://127.0.0.1:7890 ubuntu sleep infinity
```
2. 初始化镜像
```shell
apt update
apt install git gcc g++ cmake -y
apt install liblua5.4-dev libsqlite3-dev libreadline-dev libssl-dev -y
apt install libgit2-dev swig qt6-base-dev qt6-tools-dev-tools -y
```
3. 编译代码
```shell
# 下载FreeKill源码
git clone https://gitee.com/notify-ctrl/FreeKill
cd FreeKill && mkdir build && cd build
cp -r /usr/include/lua5.4/* ../include
cmake .. -DFK_SERVER_ONLY=ON
make
cd ..
ln -s build/FreeKill
```

4. 保存容器为镜像
```shell
docker commit -m "FreeKill server" fk-svr  fk-svr 
```

5. 容器中运行
```shell
docker-compose up -d
docker exec -it fk-svr bash
./FreeKill -s
```

# 主机上运行
```shell
apt install liblua5.4-dev libsqlite3-dev libreadline-dev libssl-dev -y
apt install libgit2-dev swig
mdkir build && cd build && cmake .. && make
# remove liblua5.4-dev and install liblua5.4
ln -s build/FreeKill
./FreeKill -s
```
