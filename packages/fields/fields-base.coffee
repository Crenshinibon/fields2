Fields.forms = new Meteor.Collection 'fields-forms'

Fields._collections = {}
Fields._getCollection = (name) ->
    unless name?
        return [new Meteor.Collection(null), true]
    
    unless Fields._collections[name]?
        Fields._collections[name] = new Meteor.Collection name
        [Fields._collections[name], true]
    else
        [Fields._collections[name], false]
        
