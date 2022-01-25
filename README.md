# react-native-loco-kit

## Getting started

`$ npm install react-native-loco-kit --save`

### Mostly automatic installation

`$ react-native link react-native-loco-kit`

## Usage
```javascript
import LocoKit from 'react-native-loco-kit';
import { ... NativeEventEmitter } from 'react-native';

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
```
