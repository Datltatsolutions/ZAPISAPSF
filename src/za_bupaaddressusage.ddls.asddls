/********** GENERATED on 10/21/2023 at 14:35:28 by CB9980000011**************/
 @OData.entitySet.name: 'A_BuPaAddressUsage' 
 @OData.entityType.name: 'A_BuPaAddressUsageType' 
 define root abstract entity ZA_BUPAADDRESSUSAGE { 
 key BusinessPartner : abap.char( 10 ) ; 
 key ValidityEndDate : tzntstmpl ; 
 key AddressUsage : abap.char( 10 ) ; 
 key AddressID : abap.char( 10 ) ; 
 @Odata.property.valueControl: 'ValidityStartDate_vc' 
 ValidityStartDate : tzntstmpl ; 
 ValidityStartDate_vc : RAP_CP_ODATA_VALUE_CONTROL ; 
 @Odata.property.valueControl: 'StandardUsage_vc' 
 StandardUsage : abap_boolean ; 
 StandardUsage_vc : RAP_CP_ODATA_VALUE_CONTROL ; 
 @Odata.property.valueControl: 'AuthorizationGroup_vc' 
 AuthorizationGroup : abap.char( 4 ) ; 
 AuthorizationGroup_vc : RAP_CP_ODATA_VALUE_CONTROL ; 
 
 } 
