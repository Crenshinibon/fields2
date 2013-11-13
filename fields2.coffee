Proposals = new Meteor.Collection 'proposals'


projectTypes = () ->
    ['Simple', 'Complex']

proposalForm = 
    summary: 
        label: 'Management Summary'
        type: 'richtext'
        default: 'Some Description'
        comments: true
    projectType: 
        label: 'Project Type'
        type: 'select'
        choices: projectTypes()
    codeName: 
        label: 'Code Name'
        type: 'simpletext'
        default: 'None'
        hint: 'You can give your project a code name.'
    cost:
        label: 'Costs'
        type: 'number'
        hint: 'Enter the estimated costs engaging this project.'
    risks:
        label: 'Risks'
        type: 'complex'
        elements:
            name: 
                label: 'Name'
                type: 'simpletext'
            probability:
                label: 'Probability'
                type: 'select'
                default: 'Medium'
                choices: ['High','Medium','Low']
            desc:
                label: 'Description'
                typ: 'richtext'

if Meteor.isServer
    
    Meteor.startup () ->
        Fields.initForm 'proposal', proposalForm
    
    
    Meteor.startup () ->
        if Proposals.find().count() is 0
            Proposals.insert
                name: 'The Ring'
            Proposals.insert
                name: 'The Others'
            Proposals.insert
                name: 'Texas Chainsaw Massacre'
    
    Meteor.publish 'proposals', () ->
        Proposals.find()
    

if Meteor.isClient
    
    Meteor.subscribe 'proposals'
    
    Template.main.proposals = () ->
        Proposals.find()
        
    Template.main.selectedProposal = () ->
        pId = Session.get 'selectedProposal'
        Proposals.findOne {_id: pId}
    
    Template.main.events
        'click tr.proposal': (e) ->
            Session.set 'selectedProposal', @_id
            
            
        