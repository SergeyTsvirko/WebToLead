public with sharing class ConvertLeadHandler {
    public static void leadTriggerIsAfterConvert(List<Lead> leadList) {
        Map<Id, Id> leadConvertMap = new Map<Id, Id>();
        for(Lead recordLead: leadList) {
            leadConvertMap.put(recordLead.Id, recordLead.ConvertedContactId);
        }
        
        List <Subscription__c> subscriptionList = [SELECT Name, Contact__c, Lead__c
                                                   FROM Subscription__c
                                                   WHERE Lead__c IN: leadConvertMap.keySet()];
        
        for(Subscription__c recordSub :subscriptionList) {
            recordSub.Contact__c = leadConvertMap.get(recordSub.Lead__c);
        } 
        if(subscriptionList != null && !subscriptionList.isEmpty()) {
           update subscriptionList;   
        }
    }
}