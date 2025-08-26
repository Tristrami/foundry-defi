## 解决引入问题

涉及 remap 的导入都报错

```
xxx not found: File import callback not supported
```

下载 solc 二进制文件，下载 `.js` 格式的文件

```
https://github.com/ethereum/solidity/releases
```

在 solidity 插件里面设置使用本地 solc 编译器，选 `localFile`

```json
"solidity.defaultCompiler": "localFile"
```

指定本地 solc 路径

```json
"solidity.compileUsingLocalVersion": "E:\\software\\solc\\soljson.js"
```

导出所有 remapping，放到 `"solidity.remappings"` 设置项，remappings.txt 可以不用保留

```shell
forge remappings > remappings.txt
```

完整设置

```json
"solidity.formatter": "forge",
"solidity.remappings": [
    "@chainlink/contracts/=lib/chainlink-brownie-contracts/contracts/",
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "chainlink-brownie-contracts/=lib/chainlink-brownie-contracts/contracts/src/v0.6/vendor/@arbitrum/nitro-contracts/src/",
    "erc4626-tests/=lib/openzeppelin-contracts/lib/erc4626-tests/",
    "forge-std/=lib/forge-std/src/",
    "foundry-devops/=lib/foundry-devops/",
    "halmos-cheatcodes/=lib/openzeppelin-contracts/lib/halmos-cheatcodes/src/",
    "openzeppelin-contracts/=lib/openzeppelin-contracts/",
],
"solidity.defaultCompiler": "localFile",
"solidity.compileUsingLocalVersion": "E:\\software\\solc\\soljson.js",
```

如果还是不行，试下这个设置，最后是这个设置解决了

```json
"solidity.monoRepoSupport": false
```


### 查看合约的所有函数

```shell
forge inspect MiaoEngine methods
```

## Invariant Test

### 分类

- Stateful fuzz test：对合约所有函数进行随机调用，保留合约状态
- Stateless fuzz test：对合约指定函数进行随机测试，不保留合约状态

### 测试配置

```toml
[invariant]
runs = 128
depth = 128
fail_on_revert = false # 可以按需调整
```

Invariant 测试函数的函数名需要以 `invariant_` 作为前缀

### 官方文档

https://getfoundry.sh/forge/advanced-testing/invariant-testing


