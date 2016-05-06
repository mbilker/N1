import React from 'react';
import ReactDOM from 'react-dom';
import {
  Simulate,
  findRenderedDOMComponentWithClass,
} from 'react-addons-test-utils';

import {DateUtils} from 'nylas-exports'
import DateInput from '../../src/components/date-input';
import {renderIntoDocument} from '../nylas-test-utils'

const {findDOMNode} = ReactDOM;

const makeInput = (props = {}) => {
  const input = renderIntoDocument(<DateInput {...props} dateFormat="blah" />);
  if (props.initialState) {
    input.setState(props.initialState)
  }
  return input
};

describe('DateInput', function dateInput() {
  describe('onInputKeyDown', () => {
    it('should submit the input if Enter or Escape pressed', () => {
      const onSubmitDate = jasmine.createSpy('onSubmitDate')
      const component = makeInput({onSubmitDate: onSubmitDate})
      const inputNode = ReactDOM.findDOMNode(component).querySelector('input')
      const stopPropagation = jasmine.createSpy('stopPropagation')
      const keys = ['Enter', 'Return']
      inputNode.value = 'tomorrow'
      spyOn(DateUtils, 'futureDateFromString').andReturn('someday')
      spyOn(component, 'setState')

      keys.forEach((key) => {
        Simulate.keyDown(inputNode, {key, stopPropagation})
        expect(stopPropagation).toHaveBeenCalled()
        expect(onSubmitDate).toHaveBeenCalledWith('someday', 'tomorrow')
        expect(component.setState).toHaveBeenCalledWith({inputDate: null})
        stopPropagation.reset()
        onSubmitDate.reset()
        component.setState.reset()
      })
    });
  });

  describe('render', () => {
    beforeEach(() => {
      spyOn(DateUtils, 'format').andReturn('formatted')
    });

    it('should render a date interpretation if a date has been inputted', () => {
      const component = makeInput({initialState: {inputDate: 'something!'}})
      spyOn(component, 'setState')
      const dateInterpretation = findDOMNode(findRenderedDOMComponentWithClass(component, 'date-interpretation'))

      expect(dateInterpretation.textContent).toEqual('formatted')
    });

    it('should not render a date interpretation if no input date available', () => {
      const component = makeInput({initialState: {inputDate: null}})
      spyOn(component, 'setState')
      expect(() => {
        findRenderedDOMComponentWithClass(component, 'date-interpretation')
      }).toThrow()
    });
  });
});
