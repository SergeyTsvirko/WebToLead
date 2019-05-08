trigger LeadTrigger on Lead (after insert, after update) {
    
    if (Trigger.isAfter && Trigger.isInsert) {
        WebToLeadHandler.leadTriggerIsAfterInsert(Trigger.new);    
    }  
    
    if (Trigger.isAfter && Trigger.isupdate && Trigger.new != Trigger.old) {
        ConvertLeadHandler.leadTriggerIsAfterConvert(Trigger.new);
    }
}