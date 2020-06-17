import React, { Component } from 'react';
import DateTimePicker from 'react-datetime-picker';
 
class MyApp extends Component {

  constructor (props) {
    super(props);
    this.state = {
        value: null
    };
    this.setValue = this.setValue.bind(this);
  }

  setValue (value) {
    this.setState({ value }, () => this.props.setValue(value));
  }

  state = {
    date: new Date(),
  }
  onChange = date => this.setState({ date })
 
  render() {
    return (
      <div>
        <DateTimePicker
          onChange={this.onChange}
          value={this.state.date}
          setValue={this.state.date}
        />
      </div>
    );
  }
}

export default MyApp;