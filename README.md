# build docker LSF 10.1 CE docker image

1. git clone git@github.com:huxiaoliang/lsf_app.git
2. cd lsf_app
3. docker build --rm --cpuset-cpus="1,3" -t lsf:10.1 .
