import React from 'react';

function ListensToFluxStore(ComposedComponent, {stores, getStateFromStores}) {
  return class extends ComposedComponent {
    static containerRequired = false;

    static propTypes = {}

    constructor(props) {
      super(props);
      this._unlisteners = [];
      this.state = getStateFromStores(props);
    }

    componentDidMount() {
      stores.forEach((store) => {
        this._unlisteners.push(store.listen(() => {
          this.setState(getStateFromStores(this.props));
        }));
      });
    }

    componentWillReceiveProps(nextProps) {
      this.setState(getStateFromStores(nextProps));
    }

    componentWillUnmount() {
      for (const unlisten of this._unlisteners) {
        unlisten();
      }
      this._unlisteners = [];
    }

    render() {
      return <ComposedComponent {...this.props} {...this.state} />;
    }
  };
}

export default ListensToFluxStore
