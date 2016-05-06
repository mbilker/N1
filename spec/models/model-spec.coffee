Model = require '../../src/flux/models/model'
Utils = require '../../src/flux/models/utils'
Attributes = require '../../src/flux/attributes'
{isTempId} = require '../../src/flux/models/utils'
_ = require 'underscore'

describe "Model", ->
  describe "constructor", ->
    it "should accept a hash of attributes and assign them to the new Model", ->
      attrs =
        id: "A",
        accountId: "B"
      m = new Model(attrs)
      expect(m.id).toBe(attrs.id)
      expect(m.accountId).toBe(attrs.accountId)

    it "by default assigns things passed into the id constructor to the serverId", ->
      attrs =
        id: "A",
      m = new Model(attrs)
      expect(m.serverId).toBe(attrs.id)

    it "by default assigns values passed into the id constructor that look like localIds to be a localID", ->
      attrs =
        id: "A",
      m = new Model(attrs)
      expect(m.serverId).toBe(attrs.id)

    it "assigns serverIds and clientIds", ->
      attrs =
        clientId: "local-A",
        serverId: "A",
      m = new Model(attrs)
      expect(m.serverId).toBe(attrs.serverId)
      expect(m.clientId).toBe(attrs.clientId)
      expect(m.id).toBe(attrs.serverId)

    it "throws an error if you attempt to manually assign the id", ->
      m = new Model(id: "foo")
      expect( -> m.id = "bar" ).toThrow()

    it "automatically assigns a clientId (and id) to the model if no id is provided", ->
      m = new Model
      expect(Utils.isTempId(m.id)).toBe true
      expect(Utils.isTempId(m.clientId)).toBe true
      expect(m.serverId).toBeUndefined()

  describe "attributes", ->
    it "should return the attributes of the class EXCEPT the id field", ->
      m = new Model()
      retAttrs = _.clone(m.constructor.attributes)
      delete retAttrs["id"]
      expect(m.attributes()).toEqual(retAttrs)

  describe "clone", ->
    it "should return a deep copy of the object", ->
      class SubSubmodel extends Model
        @attributes: _.extend {}, Model.attributes,
          'value': Attributes.Number
            modelKey: 'value'
            jsonKey: 'value'

      class Submodel extends Model
        @attributes: _.extend {}, Model.attributes,
          'testNumber': Attributes.Number
            modelKey: 'testNumber'
            jsonKey: 'test_number'
          'testArray': Attributes.Collection
            itemClass: SubSubmodel
            modelKey: 'testArray'
            jsonKey: 'test_array'

      old = new Submodel(testNumber: 4, testArray: [new SubSubmodel(value: 2), new SubSubmodel(value: 6)])
      clone = old.clone()

      # Check entire trees are equivalent
      expect(old.toJSON()).toEqual(clone.toJSON())
      # Check object identity has changed
      expect(old.constructor.name).toEqual(clone.constructor.name)
      expect(old.testArray).not.toBe(clone.testArray)
      # Check classes
      expect(old.testArray[0]).not.toBe(clone.testArray[0])
      expect(old.testArray[0].constructor.name).toEqual(clone.testArray[0].constructor.name)

  describe "fromJSON", ->
    beforeEach ->
      class SubmodelItem extends Model

      class Submodel extends Model
        @attributes: _.extend {}, Model.attributes,
          'testNumber': Attributes.Number
            modelKey: 'testNumber'
            jsonKey: 'test_number'
          'testBoolean': Attributes.Boolean
            modelKey: 'testBoolean'
            jsonKey: 'test_boolean'
          'testCollection': Attributes.Collection
            modelKey: 'testCollection'
            jsonKey: 'test_collection'
            itemClass: SubmodelItem

      @json =
        'id': '1234'
        'test_number': 4
        'test_boolean': true
        'daysOld': 4
        'account_id': 'bla'
      @m = new Submodel

    it "should assign attribute values by calling through to attribute fromJSON functions", ->
      spyOn(Model.attributes.accountId, 'fromJSON').andCallFake (json) ->
        'inflated value!'
      @m.fromJSON(@json)
      expect(Model.attributes.accountId.fromJSON.callCount).toBe 1
      expect(@m.accountId).toBe('inflated value!')

    it "should not touch attributes that are missing in the json", ->
      @m.fromJSON(@json)
      expect(@m.object).toBe(undefined)

      @m.object = 'abc'
      @m.fromJSON(@json)
      expect(@m.object).toBe('abc')

    it "should not do anything with extra JSON keys", ->
      @m.fromJSON(@json)
      expect(@m.daysOld).toBe(undefined)

    describe "Attributes.Number", ->
      it "should read number attributes and coerce them to numeric values", ->
        @m.fromJSON('test_number': 4)
        expect(@m.testNumber).toBe(4)

        @m.fromJSON('test_number': '4')
        expect(@m.testNumber).toBe(4)

        @m.fromJSON('test_number': 'lolz')
        expect(@m.testNumber).toBe(null)

        @m.fromJSON('test_number': 0)
        expect(@m.testNumber).toBe(0)

    describe "Attributes.Collection", ->
      it "should parse and inflate items", ->
        @m.fromJSON('test_collection': [{id: '123'}])
        expect(@m.testCollection.length).toBe(1)
        expect(@m.testCollection[0].id).toBe('123')
        expect(@m.testCollection[0].constructor.name).toBe('SubmodelItem')

      it "should be fine with malformed arrays", ->
        @m.fromJSON('test_collection': [null])
        expect(@m.testCollection.length).toBe(0)
        @m.fromJSON('test_collection': [])
        expect(@m.testCollection.length).toBe(0)
        @m.fromJSON('test_collection': null)
        expect(@m.testCollection.length).toBe(0)

    describe "Attributes.Boolean", ->
      it "should read `true` or true and coerce everything else to false", ->
        @m.fromJSON('test_boolean': true)
        expect(@m.testBoolean).toBe(true)

        @m.fromJSON('test_boolean': 'true')
        expect(@m.testBoolean).toBe(true)

        @m.fromJSON('test_boolean': 4)
        expect(@m.testBoolean).toBe(false)

        @m.fromJSON('test_boolean': '4')
        expect(@m.testBoolean).toBe(false)

        @m.fromJSON('test_boolean': false)
        expect(@m.testBoolean).toBe(false)

        @m.fromJSON('test_boolean': 0)
        expect(@m.testBoolean).toBe(false)

        @m.fromJSON('test_boolean': null)
        expect(@m.testBoolean).toBe(false)

  describe "toJSON", ->
    beforeEach ->
      @model = new Model
        id: "1234",
        accountId: "ACD"

    it "should return a JSON object and call attribute toJSON functions to map values", ->
      spyOn(Model.attributes.accountId, 'toJSON').andCallFake (json) ->
        'inflated value!'

      json = @model.toJSON()
      expect(json instanceof Object).toBe(true)
      expect(json.id).toBe('1234')
      expect(json.account_id).toBe('inflated value!')

    it "should surface any exception one of the attribute toJSON functions raises", ->
      spyOn(Model.attributes.accountId, 'toJSON').andCallFake (json) ->
        throw new Error("Can't convert value into JSON format")
      expect(-> @model.toJSON()).toThrow()

  describe "matches", ->
    beforeEach ->
      @model = new Model
        id: "1234",
        accountId: "ACD"

      @truthyMatcher =
        evaluate: (model) -> true
      @falsyMatcher =
        evaluate: (model) -> false

    it "should run the matchers and return true iff all matchers pass", ->
      expect(@model.matches([@truthyMatcher, @truthyMatcher])).toBe(true)
      expect(@model.matches([@truthyMatcher, @falsyMatcher])).toBe(false)
      expect(@model.matches([@falsyMatcher, @truthyMatcher])).toBe(false)

    it "should pass itself as an argument to the matchers", ->
      spyOn(@truthyMatcher, 'evaluate').andCallFake (param) =>
        expect(param).toBe(@model)
      @model.matches([@truthyMatcher])
