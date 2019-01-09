## helm-charts
使用 github pages 做了一个 charts 仓库的镜像，由于默认的 https://kubernetes-charts.storage.googleapis.com/ 容易被墙 ， 每天更新一次

### 用法
```bash
helm repo remove stable
helm repo add stable https://babyshen.github.io/helm-charts-mirror/
helm repo update
helm search mysql
```

#### 本文地址
https://github.com/babyshen/helm-charts-mirror/

##### Ref
- https://github.com/kuops/helm-charts-mirror
