# MBox Dev

MBox 的插件开发库，使用该插件进行 MBox 的插件开发。

## Usage

### 创建一个插件 (eg: MBoxMyPlugin)

1. 首先先要有一个 Workspace
```shell
$ mkdir MBoxPlugin
$ cd MBoxPlugin
$ mbox init plugin # plugin 是开发插件需要用到的插件集合
```

2. 创建一个仓库
```shell
$ mbox new mbox-my-plugin
```

我们建议插件采用相同的命名风格：

- 插件名是大写驼峰，eg: MBoxMyPlugin
- 仓库名是小写中划线，eg: mbox-my-plugin
- 必须以 `MBox` 和 `mbox` 开头

3. 使用指定模版创建一个插件，有哪些有效模版，可以通过 `mbox plugin dev --help` 命令查看。
```shell
$ mbox plugin dev Native
```

### 构建一个插件

```shell
$ mbox plugin build
```

默认输出在 `Workspace/release` 目录

## Command

### mbox plugin build [NAME [...]]
    编译指定 NAME 的插件，如果 NAME 为空，则编译当前 Workspace 下所有的插件。

Arguments:

    NAME    [Optional] Plugin Names, otherwise will release all plugins.

Options:

    --stage         The build stage Avaliable: Launcher/Resource/Setting/Native/Ruby/Electron
    --output-dir    The directory for the output

Flags:

    --force       Force release exists version
    --clean       Clean output directory. Defaults: YES if no stage options.


### mbox plugin dev TEMPLATE [NAME]

    使用指定模版创建一个插件

Arguments:

    TEMPLATE    Plugin Template. Avaliable: Launcher/Resource/Setting/Native/Ruby
    NAME        [Optional] Plugin Name (eg: MBoxCore)

## Contributing
Please reference the section [Contributing](https://github.com/MBoxPlus/mbox#contributing)

## License
MBox is available under [GNU General Public License v2.0 or later](./LICENSE).