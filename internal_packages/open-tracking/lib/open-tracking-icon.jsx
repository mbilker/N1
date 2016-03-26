import _ from 'underscore';
import {React} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import {PLUGIN_ID} from './open-tracking-constants'


export default class OpenTrackingIcon extends React.Component {
  static displayName = 'OpenTrackingIcon';

  static propTypes = {
    thread: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromThread(props.thread)
  }

  componentWillReceiveProps(newProps) {
    this.setState(this._getStateFromThread(newProps.thread));
  }

  _getStateFromThread(thread) {
    const messages = thread.metadata;
    if ((messages || []).length === 0) { return {opened: false, hasMetadata: false} }
    const last = _.last(_.filter(messages, m => !m.draft))
    const meta = last.metadataForPluginId(PLUGIN_ID)
    const hasMetadata = meta && meta.open_count != null
    return {
      hasMetadata,
      opened: hasMetadata && meta.open_count > 0,
    };
  }

  _renderImage() {
    return (
      <RetinaImg
        className={this.state.opened ? "opened" : "unopened"}
        url="nylas://open-tracking/assets/icon-tracking-read@2x.png"
        mode={RetinaImg.Mode.ContentIsMask} />
    );
  }

  render() {
    const title = this.state.opened ? "This message has been read at least once" : "This message has not been read";
    return (
      <div title={title} className="open-tracking-icon">
        {this.state.hasMetadata ? this._renderImage() : null}
      </div>
    );
  }
}
