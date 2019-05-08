public with sharing class WebToLeadHandler {
    private static void leadTriggerIsAfterInsert(List<Lead> leadList) {
        
        List<Lead> withoutDomenLeadList = new List<Lead>();
        if(leadList != null && !leadList.isEmpty()) {
            withoutDomenLeadList = checkEmailDomain(leadList);
        }
        
        if(withoutDomenLeadList != null && !withoutDomenLeadList.isEmpty()) {
            checkLeadList(withoutDomenLeadList);
        }        
    }
    
    private static List<Lead> checkEmailDomain(List<lead> leadList) {
        GenericResult result = getListsEmailDomain(leadList);
        
        if(result.withDomenLeadList != null && !result.withDomenLeadList.isEmpty()) {
            result = checkContactAvailability(result.withDomenLeadList);
        } 
        
        if(result.leadWithoutContactList != null && !result.leadWithoutContactList.isEmpty()) {
            creatingSubscription(result.leadWithoutContactList);
        }
        
        List<Subscription__c> subscriptionList = new List<Subscription__c>();
        if(result.contactInStockList != null && !result.contactInStockList.isEmpty()) {
            subscriptionList = checkSubscriptionAvailability(result.contactInStockList);
        }
        
        List<Lead> leadWithoutContactSub = checkSubWithRelevantContract(subscriptionList, result);
        if(leadWithoutContactSub != null && !leadWithoutContactSub.isEmpty()) {
            creatingSubscription(leadWithoutContactSub);
        }
        
        return result.withoutDomenLeadList;
    }
    
    private static List<Lead> checkSubWithRelevantContract(List<Subscription__c> subscriptionList, GenericResult result) {
        Set<Id> contactIdSet = new Set<Id>();
        for(Subscription__c recordSubscription: subscriptionList) {
            if(recordSubscription.Start_date__c < Date.today() && recordSubscription.End_date__c > Date.today()) {
                contactIdSet.add(recordSubscription.Contact__c);
            }
        }
        
        Set<String> contactEmailSet = new Set<String>();
        for(Contact recordContact: result.contactInStockList) {
            if(contactIdSet.contains(recordContact.Id)) {
                sendEmail(recordContact.Id, 'leadAboutExplanation');
            } else {
                contactEmailSet.add(recordContact.Email);
            }
        }
        
        List<Lead> leadWithoutContactSub = new List<Lead>();
        for(Lead recordLead: result.withDomenLeadList) {
            if(contactEmailSet.contains(recordLead.Email)) {
                leadWithoutContactSub.add(recordLead);
            }
        }
        
        return leadWithoutContactSub;
    }
    
    private static GenericResult getListsEmailDomain(List<Lead> leadList) {
        String domainList = '';
        for(Lead recordLead: leadList) {
            domainList = domainList + '"' + recordLead.Email.substringAfterLast('@') + '"' ;
        }
        
        List<List<sObject>> searchList = search.query('FIND \' ' + domainList.replace('""', '" or "') + 
                                                      '\' IN ALL FIELDS RETURNING Contract(Email_Domains__c)');
        
        Set<String> domainSet = new Set<String>();
        if(searchList != null && !searchList.isEmpty()) {
            for(sObject recordContract:searchList[0]) {
                domainSet.add((String)recordContract.get('Email_Domains__c'));
            }
        }
        
        GenericResult result = new GenericResult();
        
        for(Lead recordLead: leadList) {
            if(domainSet.contains(recordLead.Email.substringAfterLast('@'))) {
                result.withDomenLeadList.add(recordLead);
            } else {
                result.withoutDomenLeadList.add(recordLead);
            }
        }
        List<Object> objectLeadList = new List<Object>(); 
        List<List<Lead>> leadResultList = new List<List<Lead>>();
        
        return result;
    }
    
    private static void checkLeadList(List<lead> withoutDomenLeadList) {
        List<Lead> duplicateLeadList = checkLeadDuplicate(withoutDomenLeadList);
        
        List<Lead> absentLeadList = sendMessageToLead(duplicateLeadList, withoutDomenLeadList);
        GenericResult result = new GenericResult();
        
        if(absentLeadList != null && !absentLeadList.isEmpty()) {
            result = checkContactAvailability(absentLeadList);
        }
        
        if(result.leadWithoutContactList != null && !result.leadWithoutContactList.isEmpty()) {
            creatingSubscription(result.leadWithoutContactList);
        }
        
        List<Subscription__c> subscriptionList = new List<Subscription__c>();
        
        if(result.contactInStockList != null && !result.contactInStockList.isEmpty()) {
            subscriptionList = checkSubscriptionAvailability(result.contactInStockList);
        }
        
        Set<Id> contactIdSet = new Set<Id>();
        for(Subscription__c recordSubscription: subscriptionList) {
            contactIdSet.add(recordSubscription.Contact__c);
        }
        
        sendMessageToContact(result.contactInStockList, contactIdSet);   
    }
    
    @future(callout=true)
    private static void sendEmail(Id personInStockList, String templatesName) {
        EmailTemplate et = [SELECT Id FROM EmailTemplate WHERE Name =: templatesName LIMIT 1];
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTemplateId(et.Id);
        mail.setTargetObjectId(personInStockList);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
    
    private static void sendMessageToContact(List<Contact> contactInStockList, Set<Id> contactIdSet) {
        for(Contact recordContact: contactInStockList) {
            if(contactIdSet.contains(recordContact.Id)) {
                sendEmail(recordContact.Id, 'leadAboutExplanation');
            } else {
                sendEmail(recordContact.Id, 'leadAboutDecline');
            }
        }
    }
    
    private static List<Lead> checkLeadDuplicate(List<Lead> leadList) {
        List<String> leadEmailList = new List<String>();
        List<Id> leadIdList = new List<Id>();
        for(Lead leadRecord: leadList) {
            if(leadRecord.Email != null) {
                leadEmailList.add(leadRecord.Email);
                leadIdList.add(leadRecord.Id);
            } 
        }
        
        return [SELECT FirstName, LastName, Email, Company, Interests__c
                FROM Lead
                WHERE Email IN: leadEmailList AND Id NOT IN: leadIdList AND isConverted = false];
    }
    
    private static List<Lead> sendMessageToLead(List<Lead> duplicateLeadList, List<Lead> leadList) {
        List<Id> leadIdList = new List<Id>();
        
        List<String> duplicateEmail = new List<String>();
        for(Lead duplicateLeadRecord: duplicateLeadList) {
            duplicateEmail.add(duplicateLeadRecord.email);
            SendEmail(duplicateLeadRecord.Id, 'leadAboutDecline');
        }
        
        List<Lead> absentLeadList = new List<Lead>();
        List<Id> leadInStockIdToDelete = new List<Id>();
        
        for(Lead leadRecord: leadList) {
            if(!duplicateEmail.contains(leadRecord.Email)) {
                absentLeadList.add(leadRecord);
            } else {
                leadInStockIdToDelete.add(leadRecord.Id);
            }
        }
        
        Database.delete(leadInStockIdToDelete);
        return absentLeadList;
    }
    
    private static void creatingSubscription(List<Lead> leadList) {
        List<leadInterest__c> interestList = leadInterest__c.getAll().values();
        String interest; 
        if(interestList != null && !interestList.isEmpty()) {
            interest = interestList[0].Interest__c;
        }
        
        Id trialRecordTypeId = Schema.SObjectType.Subscription__c.getRecordTypeInfosByName().get('Trial').getRecordTypeId();
        List<Subscription__c> subscriptionList = new List<Subscription__c>();
        List<Id> leadIdList = new List<id>();
        for(Lead leadRecord: leadList) {
            if(leadRecord.Interests__c != null) {
                List<String> interestsList = leadRecord.Interests__c.split(';');
                if(interestsList.contains(interest)) {
                    Subscription__c subscription = new Subscription__c(Name = leadRecord.LastName + String.valueOf(Date.today()), 
                                                                       RecordTypeId = trialRecordTypeId, Lead__c = leadRecord.Id, 
                                                                       Start_date__c = Date.today(), End_date__c = Date.today() + 14);
                    subscriptionList.add(subscription);
                    sendEmail(leadRecord.Id, 'leadAboutSubscription');
                }
            }
        }
        
        if(subscriptionList != null && !subscriptionList.isEmpty()) {
            insert subscriptionList;
        }        
    }
    
    private static GenericResult checkContactAvailability(List<Lead> leadList) {
        List<String> emailLeadsList = new List<String>();
        for(Lead leadRecord: leadList) {
            emailLeadsList.add(leadRecord.Email);
        }
        
        GenericResult result = new GenericResult();
        result.contactInStockList = [SELECT LastName, FirstName, Email
                                     FROM Contact
                                     WHERE Email IN: emailLeadsList];
        
        List<String> contactEmailList = new List<String>();
        for(Contact recordContact: result.contactInStockList) {
            contactEmailList.add(recordContact.Email);
        }
        
        for(Lead leadRecord: leadList) {
            if(!contactEmailList.contains(leadRecord.Email)) {
                result.leadWithoutContactList.add(leadRecord);
            }
        }
        
        return result;
    }  
    
    private static List<Subscription__c> checkSubscriptionAvailability(List<Contact> contactInStockList) {
        List<Id> contactIdList = new List<Id>();
        for(Contact recordContact: contactInStockList) {
            contactIdList.add(recordContact.Id);
        }
        
        List<Subscription__c> subscriptionList = [SELECT Name, Contact__c, Start_date__c, End_date__c
                                                  FROM Subscription__c
                                                  WHERE Contact__c IN: contactIdList];
        return subscriptionList;
    }
}