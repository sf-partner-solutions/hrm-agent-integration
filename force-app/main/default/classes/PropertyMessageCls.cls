public with sharing class PropertyMessageCls {

  public String propertyId{get;set;}
  public Location__c property {get;set;}
  public string propertyInactiveTaxGroupMessage{get;set;}
  public boolean propertyInactiveTaxGroup{get;set;}

  public string propertyIsLimitedServiceMessage{get;set;}
  public boolean propertyIsLimitedService{get;set;}

  public string propertyIsInactiveMessage{get;set;}
  public boolean propertyIsInactive{get;set;}

  public boolean showBlock{get;set;}
  public string defaultMessage {get;set;}

     public PropertyMessageCls(ApexPages.StandardController stdController)
    {
       propertyId = String.escapeSingleQuotes(EncodingUtil.urlEncode(ApexPages.currentPage().getParameters().get('id'), 'UTF-8'));

      Security.checkAreFieldsAccessible('Location__c', new List<String>{'Id', 'IsLimitedService__c', 'IsActive__c'});

    //US 457986 - Replaced Location query with LocationSelector class method
    List<id> listLocationid = new List<id>{propertyId};
    List<Location__c> lstLocation = LocationsSelector.getLocationsById(listLocationid).values();
    if(!lstLocation.IsEmpty()){
      property = lstLocation[0];
    }

        propertyInactiveTaxGroupMessage = '';
        propertyInactiveTaxGroup = false;

        propertyIsLimitedServiceMessage = '';
        propertyIsLimitedService = false;

        propertyIsInactiveMessage = '';
        propertyIsInactive = false;

        showBlock = false;
        CreateMessages();

    defaultMessage = Label.PropertyMessageDefault;
    }

    public void CreateMessages()
    {
      Security.checkAreFieldsAccessible('Location__c', new List<String>{'DefaultTaxGroup__c'});

    boolean isInvalid = TaxGroupCls.isDefaultInactiveForLocation(propertyId);
      if(isInvalid){
      propertyInactiveTaxGroupMessage = Label.PropertyInactiveTaxGroup;
          propertyInactiveTaxGroup = true;
          showBlock = true;
      }

      propertyIsLimitedService = property.IsLimitedService__c;
      if(propertyIsLimitedService) {
        propertyIsLimitedServiceMessage = Label.PropertyIsLimitedService;
        showBlock = true;
      }

      propertyIsInactive = property.IsActive__c;
      if(!propertyIsInactive) {
        propertyIsInactiveMessage = Label.PropertyIsInactive;
        showBlock = true;
      }
    }

}