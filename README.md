# react-native-loco-kit

## Getting started

`$ npm install react-native-loco-kit --save`

### Mostly automatic installation

`$ react-native link react-native-loco-kit`

## Usage
```javascript
import LocoKit from 'react-native-loco-kit';
import { ... NativeEventEmitter } from 'react-native';

export default class App extends Component<{}> {

...
    componentDidMount() {
        const bus = new NativeEventEmitter(LocoKitModule)
        bus.addListener('LocationStatusEvent', (data) => this.setState({ locationStatus: data }))
        bus.addListener('TimeLineStatusEvent', (data) => this.setState({ item: data }))
        bus.addListener('ActivityTypeEvent', (data) => this.setState({ activity: data }))
        LocoKitModule.isAvailable((available) => {
            if (available) {
                LocoKitModule.setup("<API Key Goes Here>", (result) => {
                    this.setState({ status: result })
                    LocoKitModule.start()
                });
            } else {
                this.setState({ status: "LocoKit not available" })
            }
        })
    }
...
}

```


## iOS Podfile

Required to Override 

```ruby

  ## Override Podspec due to use latest from Repo
  pod 'LocoKit', :git => 'https://github.com/sobri909/LocoKit.git', :branch => 'master'
  pod 'LocoKit/Base', :git => 'https://github.com/sobri909/LocoKit.git', :branch => 'master'
  pod 'SwiftNotes'
  pod 'GRDB.swift', '~> 4.14.0'

  post_install do |installer|
    ## Upsurge ML library requires older version of Swift
    installer.pods_project.targets.each do |target|
      if ['Upsurge'].include? "#{target}"
        target.build_configurations.each do |config|
          config.build_settings['SWIFT_VERSION'] = '4.0'
        end
      end
    end
    ## React Native Implementation
    react_native_post_install(installer)
    __apply_Xcode_12_5_M1_post_install_workaround(installer)
  end

```