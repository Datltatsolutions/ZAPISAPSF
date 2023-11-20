CLASS lhc_salesforcerequestapi DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS updateauthtoken FOR DETERMINE ON SAVE
      IMPORTING keys FOR salesforcerequestapi~updateauthtoken.
    METHODS updatefirstname FOR DETERMINE ON MODIFY
      IMPORTING keys FOR salesforcerequestapi~updatefirstname.
    METHODS validatebusinesspartnerid FOR VALIDATE ON SAVE
      IMPORTING keys FOR salesforcerequestapi~validatebusinesspartnerid.
    METHODS setupdateauthtoken FOR MODIFY
      IMPORTING keys FOR ACTION salesforcerequestapi~setupdateauthtoken.


ENDCLASS.

CLASS lhc_salesforcerequestapi IMPLEMENTATION.

  METHOD updateauthtoken.
    TRY.
        "create http destination by url; API endpoint for API sandbox
      "DATA(pr_keys) = VALUE ZTSFRQAPI( businesspartnerid = KEYS[ 1 ]-businesspartnerid ).

        Data: sucess type if_web_http_response=>http_status,
              notAuth type if_web_http_response=>http_status,
              Update type if_web_http_response=>http_status,
              create type if_web_http_response=>http_status,
              businessPartnerID type string.
        "SET VALUE
        sucess-code = 200.
        create-code = 201.
        Update-code = 204.
        notAuth-code = 401.
        notAuth-reason = 'Unauthorized'.

        READ ENTITIES OF zi_sfrqapi IN LOCAL MODE
        ENTITY SalesForceRequestAPI
        FIELDS ( salesforceaccountid ) WITH CORRESPONDING #( keys )
        RESULT DATA(sfrqapi_result).

        LOOP AT sfrqapi_result INTO DATA(sfrqapi_select).
        IF sfrqapi_select-salesforceaccountid is INITIAL OR sfrqapi_select-salesforceaccountid = ''.
            APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_Salesforce_AccountID'
                                %msg            = new_message_with_text( text     = 'Salesforce AccountID is initial.'
                               severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
           MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).
            return.
        ENDIF.

        IF sfrqapi_select-businesspartnercategory IS NOT INITIAL.
            try.
                data(lo_http_destination) =
                     cl_http_destination_provider=>create_by_url( 'https://my406848-api.s4hana.cloud.sap/sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BusinessPartner?$top=1' ).
              catch cx_http_dest_provider_error.
                "handle exception
            endtry.
            "create HTTP client by destination
            DATA(lo_web_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_http_destination ) .

            "adding headers with API Key for API Sandbox
            DATA(lo_web_http_request) = lo_web_http_client->get_http_request( ).
            lo_web_http_request->set_header_fields( VALUE #(
            (  name = 'Authorization' value = |Basic U0FNTF9CRUFSRVJfQVNTRVJUSU9OOnVOWWNjeE4pUEpiVU16Vmx6dEROaG1peER4dnV3RHFkTXRidUVHNVA=| )
            (  name = 'Accept' value = 'application/json' )
            (  name = 'x-csrf-token' value = 'FETCH' )
             ) ).

            "set request method and execute request
            DATA(lo_web_http_response) = lo_web_http_client->execute( if_web_http_client=>GET ).
            DATA(lv_response_status) = lo_web_http_response->get_status( )."GET RESPONSE STATUS


            IF lv_response_status = notAuth.
                APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_AUTHORIZATION'
                                %msg            = new_message_with_text( text     = '401 Not Unauthorized. Check authToken'
                                                               severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
                sfrqapi_select-api_result = '401 Not Unauthorized. Check authToken'.
                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).
                RETURN.
            ELSEIF lv_response_status-code <> sucess-code.
                APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_ERROR'
                                %msg            = new_message_with_text( text     = |{ lv_response_status-code } - { lv_response_status-reason }|
                                                               severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
                DATA(lv_response_text) = lo_web_http_response->get_text( )."GET RESPONSE STATUS
                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).
                RETURN.

            ENDIF.

            DATA(lv_response_x_csrf_token) = lo_web_http_response->get_header_field( 'x-csrf-token' ).
            DATA(lv_response_cookie_z91) = lo_web_http_response->get_cookie(
                                         i_name = 'SAP_SESSIONID_Z91_080'
*                                         i_path = ``
                                       ).
            DATA(lv_response_cookie_usercontext) = lo_web_http_response->get_cookie(
             i_name = 'sap-usercontext'
*             i_path = ``
            ).
        ENDIF.

        SELECT Count( * ) FROM zi_sfrqapi WHERE salesforceaccountid = @sfrqapi_select-salesforceaccountid INTO @DATA(id_count).

        IF lv_response_x_csrf_token IS NOT INITIAL AND id_count > 0." BUSINESS PARTNER EXSIST


        ELSEIF lv_response_x_csrf_token IS NOT INITIAL AND id_count = 0." BUSINESS PARTNER NOT EXSIST

            try.
                lo_http_destination =
                     cl_http_destination_provider=>create_by_url( 'https://my406848-api.s4hana.cloud.sap/sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BusinessPartner' ).
              catch cx_http_dest_provider_error.
                "handle exception
            endtry.
            "create HTTP client by destination
            lo_web_http_client = cl_web_http_client_manager=>create_by_http_destination( lo_http_destination ) .

            "adding headers with API Key for API Sandbox
            lo_web_http_request = lo_web_http_client->get_http_request( ).
            lo_web_http_request->delete_header_field( 'Authorization').
            lo_web_http_request->delete_header_field( 'Accept').
            lo_web_http_request->delete_header_field( 'x-csrf-token').
            lo_web_http_request->set_header_fields( VALUE #(
            (  name = 'Content-Type' value = 'application/json' )
            (  name = 'Authorization' value = |Basic U0FNTF9CRUFSRVJfQVNTRVJUSU9OOnVOWWNjeE4pUEpiVU16Vmx6dEROaG1peER4dnV3RHFkTXRidUVHNVA=| )
            (  name = 'Accept' value = 'application/json' )
            (  name = 'x-csrf-token' value = |{ lv_response_x_csrf_token }| )
             ) ).
            lo_web_http_request->set_cookie(
              EXPORTING
                i_name    = 'SAP_SESSIONID_Z91_080'
*                i_path    = ``
                i_value   = lv_response_cookie_z91-value
*                i_domain  = ``
*                i_expires = ``
*                i_secure  = 0
*              RECEIVING
*                r_value   =
            ).
            lo_web_http_request->set_cookie(
              EXPORTING
                i_name    = 'sap-usercontext'
*                i_path    = ``
                i_value   = lv_response_cookie_usercontext-value
*                i_domain  = ``
*                i_expires = ``
*                i_secure  = 0
*              RECEIVING
*                r_value   =
            ).
*            CATCH cx_web_message_error.
*            CATCH cx_web_message_error.
            DATA: bodyjson      TYPE string,
                  bill_to       type string,
                  ship_to       type string,
                  regis_to      type string.

            """""""""""""""""""""""""""BILL TO"""""""""""""""""""""""""""""""
            IF sfrqapi_select-billto_country IS NOT INITIAL AND sfrqapi_select-language IS NOT INITIAL.
                "bill_to = bill_to && '{'."1
                bill_to = bill_to && |"PostalCode": "{ sfrqapi_select-billto_postalcode }",|.
                bill_to = bill_to && |"Country": "{ sfrqapi_select-billto_country }",|.
                bill_to = bill_to && |"CityName": "{ sfrqapi_select-billto_cityname }",|.
                bill_to = bill_to && |"Region": "{ sfrqapi_select-billto_state }",|.
                bill_to = bill_to && |"Language": "{ sfrqapi_select-language }",|.
                bill_to = bill_to && |"StreetName": "{ sfrqapi_select-billto_streetname }",|.
                bill_to = bill_to && |"StreetPrefixName": "{ sfrqapi_select-billto_streetprefixname }",|.
                bill_to = bill_to && |"StreetSuffixName": "{ sfrqapi_select-billto_streetsuffixname }",|.
                    bill_to = bill_to && '"to_AddressUsage": {'."2
                    bill_to = bill_to && '"results": ['.        "3
                        bill_to = bill_to && '{'."4
                            bill_to = bill_to && '"AddressUsage": "BILL_TO",'.
                            bill_to = bill_to && '"StandardUsage": false'.
                        bill_to = bill_to && '}'."4
                    bill_to = bill_to && ']'."3
                    bill_to = bill_to && '}'."2

                    IF sfrqapi_select-phonenumber IS NOT INITIAL.
                        bill_to = bill_to && ',"to_PhoneNumber": {'."2
                        bill_to = bill_to && '"results": ['.        "3
                            bill_to = bill_to && '{'."4
                                bill_to = bill_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                                IF sfrqapi_select-isdefaultphonenumber = 'X'.
                                    bill_to = bill_to && |"IsDefaultPhoneNumber": true ,|.
                                else.
                                    bill_to = bill_to && |"IsDefaultPhoneNumber": false ,|.
                                ENDIF.
                                bill_to = bill_to && |"PhoneNumber": "{ sfrqapi_select-phonenumber }"|.
                            bill_to = bill_to && '}'."4
                        bill_to = bill_to && ']'."3
                        bill_to = bill_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-mobilephone IS NOT INITIAL.
                    bill_to = bill_to && ',"to_MobilePhoneNumber": {'."2
                    bill_to = bill_to && '"results": ['.        "3
                        bill_to = bill_to && '{'."4
                            bill_to = bill_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                            IF sfrqapi_select-isdefaultmobilephonenumber = 'X'.
                                bill_to = bill_to && |"IsDefaultPhoneNumber": true ,|.
                            else.
                                bill_to = bill_to && |"IsDefaultPhoneNumber": false ,|.
                            ENDIF.
                            bill_to = bill_to && |"PhoneNumber": "{ sfrqapi_select-mobilephone }"|.
                        bill_to = bill_to && '}'."4
                    bill_to = bill_to && ']'."3
                    bill_to = bill_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-emailaddress IS NOT INITIAL.
                    bill_to = bill_to && ',"to_EmailAddress": {'."2
                    bill_to = bill_to && '"results": ['.        "3
                        bill_to = bill_to && '{'."4
                            bill_to = bill_to && '"IsDefaultEmailAddress": true,'.
                            bill_to = bill_to && |"EmailAddress": "{ sfrqapi_select-emailaddress }"|.
                        bill_to = bill_to && '}'."4
                    bill_to = bill_to && ']'."3
                    bill_to = bill_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-websiteurl IS NOT INITIAL.
                    bill_to = bill_to && ',"to_URLAddress": {'."2
                    bill_to = bill_to && '"results": ['.        "3
                        bill_to = bill_to && '{'."4
                            bill_to = bill_to && '"IsDefaultURLAddress": true,'.
                            bill_to = bill_to && |"WebsiteURL": "{ sfrqapi_select-websiteurl }"|.
                        bill_to = bill_to && '}'."4
                    bill_to = bill_to && ']'."3
                    bill_to = bill_to && '}'."2
                    ENDIF.

                "bill_to = bill_to && '}'."1
            ENDIF.

            """""""""""""""""""""""""SHIP TO"""""""""""""""""""""""""""""""""
            IF sfrqapi_select-shipto_country IS NOT INITIAL AND sfrqapi_select-language IS NOT INITIAL.
                "ship_to = ship_to && '{'."1
                ship_to = ship_to && |"PostalCode": "{ sfrqapi_select-shipto_postalcode }",|.
                ship_to = ship_to && |"Country": "{ sfrqapi_select-shipto_country }",|.
                ship_to = ship_to && |"CityName": "{ sfrqapi_select-shipto_cityname }",|.
                ship_to = ship_to && |"Region": "{ sfrqapi_select-shipto_state }",|.
                ship_to = ship_to && |"Language": "{ sfrqapi_select-language }",|.
                ship_to = ship_to && |"StreetName": "{ sfrqapi_select-shipto_streetname }",|.
                ship_to = ship_to && |"StreetPrefixName": "{ sfrqapi_select-shipto_streetprefixname }",|.
                ship_to = ship_to && |"StreetSuffixName": "{ sfrqapi_select-shipto_streetsuffixname }",|.
                    ship_to = ship_to && '"to_AddressUsage": {'."2
                        ship_to = ship_to && '"results": ['.        "3
                        ship_to = ship_to && '{'."4
                            ship_to = ship_to && '"AddressUsage": "SHIP_TO",'.
                            ship_to = ship_to && '"StandardUsage": false'.
                        ship_to = ship_to && '}'."4
                        ship_to = ship_to && ']'."3
                    ship_to = ship_to && '}'."2

                    IF sfrqapi_select-phonenumber IS NOT INITIAL.
                        ship_to = ship_to && ',"to_PhoneNumber": {'."2
                        ship_to = ship_to && '"results": ['.        "3
                            ship_to = ship_to && '{'."4
                                ship_to = ship_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                                "ship_to = ship_to && |"IsDefaultPhoneNumber":{ sfrqapi_select-isdefaultphonenumber } ,|.
                                IF sfrqapi_select-isdefaultmobilephonenumber = 'X'.
                                    ship_to = ship_to && |"IsDefaultPhoneNumber": true ,|.
                                else.
                                    ship_to = ship_to && |"IsDefaultPhoneNumber": false ,|.
                                ENDIF.
                                ship_to = ship_to && |"PhoneNumber": "{ sfrqapi_select-phonenumber }"|.
                            ship_to = ship_to && '}'."4
                        ship_to = ship_to && ']'."3
                        ship_to = ship_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-mobilephone IS NOT INITIAL.
                    ship_to = ship_to && ',"to_MobilePhoneNumber": {'."2
                    ship_to = ship_to && '"results": ['.        "3
                        ship_to = ship_to && '{'."4
                            ship_to = ship_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                            "ship_to = ship_to && |"IsDefaultPhoneNumber": { sfrqapi_select-isdefaultmobilephonenumber },|.
                            IF sfrqapi_select-isdefaultmobilephonenumber = 'X'.
                                ship_to = ship_to && |"IsDefaultPhoneNumber": true ,|.
                            else.
                                ship_to = ship_to && |"IsDefaultPhoneNumber": false ,|.
                            ENDIF.
                            ship_to = ship_to && |"PhoneNumber": "{ sfrqapi_select-mobilephone }"|.
                        ship_to = ship_to && '}'."4
                    ship_to = ship_to && ']'."3
                    ship_to = ship_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-emailaddress IS NOT INITIAL.
                    ship_to = ship_to && ',"to_EmailAddress": {'."2
                    ship_to = ship_to && '"results": ['.        "3
                        ship_to = ship_to && '{'."4
                            ship_to = ship_to && '"IsDefaultEmailAddress": true,'.
                            ship_to = ship_to && |"EmailAddress": "{ sfrqapi_select-emailaddress }"|.
                        ship_to = ship_to && '}'."4
                    ship_to = ship_to && ']'."3
                    ship_to = ship_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-websiteurl IS NOT INITIAL.
                    ship_to = ship_to && ',"to_URLAddress": {'."2
                    ship_to = ship_to && '"results": ['.        "3
                        ship_to = ship_to && '{'."4
                            ship_to = ship_to && '"IsDefaultURLAddress": true,'.
                            ship_to = ship_to && |"WebsiteURL": "{ sfrqapi_select-websiteurl }"|.
                        ship_to = ship_to && '}'."4
                    ship_to = ship_to && ']'."3
                    ship_to = ship_to && '}'."2
                    ENDIF.

                "ship_to = ship_to && '}'."1
            ENDIF.

            """"""""""""""""""""""""""""REGISTER TO""""""""""""""""""""""""""""""
            IF sfrqapi_select-register_country IS NOT INITIAL AND sfrqapi_select-language IS NOT INITIAL.
                "regis_to = regis_to && '{'."1
                regis_to = regis_to && |"PostalCode": "{ sfrqapi_select-register_postalcode }",|.
                regis_to = regis_to && |"Country": "{ sfrqapi_select-register_country }",|.
                regis_to = regis_to && |"CityName": "{ sfrqapi_select-register_cityname }",|.
                regis_to = regis_to && |"Region": "{ sfrqapi_select-register_state }",|.
                regis_to = regis_to && |"Language": "{ sfrqapi_select-language }",|.
                regis_to = regis_to && |"StreetName": "{ sfrqapi_select-register_streetname }",|.
                regis_to = regis_to && |"StreetPrefixName": "{ sfrqapi_select-register_streetprefixname }",|.
                regis_to = regis_to && |"StreetSuffixName": "{ sfrqapi_select-register_streetsuffixname }",|.
                    regis_to = regis_to && '"to_AddressUsage": {'."2
                        regis_to = regis_to && '"results": ['.        "3
                        regis_to = regis_to && '{'."4
                            regis_to = regis_to && '"AddressUsage": "XXDEFAULT",'.
                            regis_to = regis_to && '"StandardUsage": false'.
                        regis_to = regis_to && '}'."4
                    regis_to = regis_to && ']'."3
                    regis_to = regis_to && '}'."2

                    IF sfrqapi_select-phonenumber IS NOT INITIAL.
                        regis_to = regis_to && ',"to_PhoneNumber": {'."2
                        regis_to = regis_to && '"results": ['.        "3
                            regis_to = regis_to && '{'."4
                                regis_to = regis_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                                "regis_to = regis_to && |"IsDefaultPhoneNumber": { sfrqapi_select-isdefaultphonenumber },|.
                                IF sfrqapi_select-isdefaultphonenumber = 'X'.
                                    regis_to = regis_to && |"IsDefaultPhoneNumber": true ,|.
                                else.
                                    regis_to = regis_to && |"IsDefaultPhoneNumber": false ,|.
                                ENDIF.
                                regis_to = regis_to && |"PhoneNumber": "{ sfrqapi_select-phonenumber }"|.
                            regis_to = regis_to && '}'."4
                        regis_to = regis_to && ']'."3
                        regis_to = regis_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-mobilephone IS NOT INITIAL.
                    regis_to = regis_to && ',"to_MobilePhoneNumber": {'."2
                    regis_to = regis_to && '"results": ['.        "3
                        regis_to = regis_to && '{'."4
                            regis_to = regis_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                            "regis_to = regis_to && |"IsDefaultPhoneNumber": { sfrqapi_select-isdefaultmobilephonenumber },|.
                            IF sfrqapi_select-isdefaultmobilephonenumber = 'X'.
                                regis_to = regis_to && |"IsDefaultPhoneNumber": true ,|.
                            else.
                                regis_to = regis_to && |"IsDefaultPhoneNumber": false ,|.
                            ENDIF.
                            regis_to = regis_to && |"PhoneNumber": "{ sfrqapi_select-mobilephone }"|.
                        regis_to = regis_to && '}'."4
                    regis_to = regis_to && ']'."3
                    regis_to = regis_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-emailaddress IS NOT INITIAL.
                    regis_to = regis_to && ',"to_EmailAddress": {'."2
                    regis_to = regis_to && '"results": ['.        "3
                        regis_to = regis_to && '{'."4
                            regis_to = regis_to && '"IsDefaultEmailAddress": true,'.
                            regis_to = regis_to && |"EmailAddress": "{ sfrqapi_select-emailaddress }"|.
                        regis_to = regis_to && '}'."4
                    regis_to = regis_to && ']'."3
                    regis_to = regis_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-websiteurl IS NOT INITIAL.
                    regis_to = regis_to && ',"to_URLAddress": {'."2
                    regis_to = regis_to && '"results": ['.        "3
                        regis_to = regis_to && '{'."4
                            regis_to = regis_to && '"IsDefaultURLAddress": true,'.
                            regis_to = regis_to && |"WebsiteURL": "{ sfrqapi_select-websiteurl }"|.
                        regis_to = regis_to && '}'."4
                    regis_to = regis_to && ']'."3
                    regis_to = regis_to && '}'."2
                    ENDIF.

                "regis_to = regis_to && '}'."1
           ENDIF.

            """"""""""""""""""""""""""""""BODY REQUEST"""""""""""""""""""""""""""""
            bodyjson = '{'."Header
            "bodyjson = bodyjson && |"BusinessPartner":"{ sfrqapi_select-businesspartnerid }",|.
            bodyjson = bodyjson && |"BusinessPartnerCategory": "{ sfrqapi_select-businesspartnercategory }",|.


            IF sfrqapi_select-yy1_fatca_1_bus = 'X'.

                bodyjson = bodyjson && |"YY1_FATCA_1_bus": true,|.
            ELSE.
                bodyjson = bodyjson && '"YY1_FATCA_1_bus": false,'.
            ENDIF.

            IF regis_to IS INITIAL AND ship_to IS INITIAL AND bill_to IS INITIAL.
                APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_ADDRESS'
                                %msg            = new_message_with_text( text     = 'Address Country Or Language is null'
                                severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).
                RETURN.
            ENDIF.

            bodyjson = bodyjson && '"to_BusinessPartnerAddress": {'."to_BusinessPartnerAddress
                bodyjson = bodyjson && '"results": ['."1
                IF regis_to IS NOT INITIAL.
                    bodyjson = bodyjson && '{'.
                    bodyjson = bodyjson && regis_to.
                    bodyjson = bodyjson && '},'.
                ENDIF.

                IF ship_to IS NOT INITIAL.
                    bodyjson = bodyjson && '{'.
                    bodyjson = bodyjson && ship_to.
                    bodyjson = bodyjson && '},'.
                ENDIF.

                IF bill_to IS NOT INITIAL.
                    bodyjson = bodyjson && '{'.
                    bodyjson = bodyjson && bill_to.
                    bodyjson = bodyjson && '},'.
                ENDIF.
                bodyjson = shift_right( val = bodyjson places = 1 ).
                bodyjson = bodyjson && ']'."1
            bodyjson = bodyjson && '},'."to_BusinessPartnerAddress

            IF sfrqapi_select-is_contact = 'X' OR sfrqapi_select-is_contact = 'true'.
                bodyjson = bodyjson && |"FirstName": "{ sfrqapi_select-firstname }",|.
                bodyjson = bodyjson && |"LastName": "{ sfrqapi_select-lastname }",|.
                bodyjson = bodyjson && '"to_BusinessPartnerRole": {'."to_BusinessPartnerRole
                    bodyjson = bodyjson && '"results": ['."1
                        bodyjson = bodyjson && '{'."2
                            bodyjson = bodyjson && '"BusinessPartnerRole": "BUP001"'.
                        bodyjson = bodyjson && '}'."2
                    bodyjson = bodyjson && ']'."1
                bodyjson = bodyjson && '}'."to_BusinessPartnerRole

            ELSE.
                bodyjson = bodyjson && |"OrganizationBPName1": "{ sfrqapi_select-organizationbpname1 }",|.
                bodyjson = bodyjson && '"to_BusinessPartnerRole": {'."to_BusinessPartnerRole
                    bodyjson = bodyjson && '"results": ['."1
                        bodyjson = bodyjson && '{'."2
                            bodyjson = bodyjson && '"BusinessPartnerRole": "FLCU00"'.
                        bodyjson = bodyjson && '},'."2
                        bodyjson = bodyjson && '{'."3
                            bodyjson = bodyjson && '"BusinessPartnerRole": "FLCU01"'.
                        bodyjson = bodyjson && '}'."3
                    bodyjson = bodyjson && ']'."1
                bodyjson = bodyjson && '},'."to_BusinessPartnerRole


                IF sfrqapi_select-industrysector <> '' AND sfrqapi_select-industrysystemtype <> ''.
                    bodyjson = bodyjson && '"to_BuPaIndustry": {'."to_BuPaIndustry
                        bodyjson = bodyjson && '"results": ['."1
                            bodyjson = bodyjson && '{'."2
                                bodyjson = bodyjson && |"IndustrySector": "{ sfrqapi_select-industrysector }",|.
                                bodyjson = bodyjson && |"IndustrySystemType": "{ sfrqapi_select-industrysystemtype }"|.
                            bodyjson = bodyjson && '}'."2
                        bodyjson = bodyjson && ']'."1
                    bodyjson = bodyjson && '},'."to_BuPaIndustry
                ENDIF.

                bodyjson = bodyjson && '"to_Customer": {'."Customer
                    bodyjson = bodyjson && |"CustomerClassification": "{ sfrqapi_select-customerclassification }",|.
                    bodyjson = bodyjson && '"to_CustomerText": {'."1
                        bodyjson = bodyjson && '"results": ['."2
                            bodyjson = bodyjson && '{'."3
                                bodyjson = bodyjson && '"Language": "VI",'.
                                bodyjson = bodyjson && '"LongTextID": "TX01",'.
                                bodyjson = bodyjson && |"LongText": "{ sfrqapi_select-text }"|.
                            bodyjson = bodyjson && '}'."3
                        bodyjson = bodyjson && ']'."2
                    bodyjson = bodyjson && '},'."1

                    bodyjson = bodyjson && '"to_CustomerSalesArea": {'."1
                        bodyjson = bodyjson && '"results": ['."2
                            bodyjson = bodyjson && '{'."3
                                bodyjson = bodyjson && |"SalesOrganization": "{ sfrqapi_select-salesorganization }",|.
                                bodyjson = bodyjson && |"DistributionChannel": "{ sfrqapi_select-distributionchannel }",|.
                                bodyjson = bodyjson && |"Division": "{ sfrqapi_select-division }",|.
                                bodyjson = bodyjson && |"Currency": "{ sfrqapi_select-currency }",|.
                                bodyjson = bodyjson && '"to_SalesAreaTax": {'."4
                                    bodyjson = bodyjson && '"results": ['."5
                                        bodyjson = bodyjson && '{'."6
                                            bodyjson = bodyjson && '"CustomerTaxCategory": "TTX1",'.
                                            bodyjson = bodyjson && |"CustomerTaxClassification": "{ sfrqapi_select-customertaxclassification }"|.
                                        bodyjson = bodyjson && '}'."6
                                    bodyjson = bodyjson && ']'."5
                                bodyjson = bodyjson && '}'."4
                            bodyjson = bodyjson && '}'."3
                        bodyjson = bodyjson && ']'."2
                    bodyjson = bodyjson && '},'."1

                    bodyjson = bodyjson && '"to_CustomerCompany": {'."1
                        bodyjson = bodyjson && '"results": ['."2
                            bodyjson = bodyjson && '{'."3
                                bodyjson = bodyjson && |"CompanyCode": "{ sfrqapi_select-companycode }",|.
                                bodyjson = bodyjson && |"ReconciliationAccount": "{ sfrqapi_select-reconciliationaccount }",|.
                                bodyjson = bodyjson && |"PaymentTerms": "{ sfrqapi_select-paymentterms }"|.
                            bodyjson = bodyjson && '}'."3
                        bodyjson = bodyjson && ']'."2
                    bodyjson = bodyjson && '}'."1
                bodyjson = bodyjson && '}'."Customer
            ENDIF.
            bodyjson = bodyjson && '}'.

            "set request method and execute request

            lo_web_http_request->set_text( bodyjson ).

            lo_web_http_response = lo_web_http_client->execute( if_web_http_client=>POST ).

            lv_response_status = lo_web_http_response->get_status( )."GET RESPONSE STATUS
            DATA(lv_response) = lo_web_http_response->get_text( ).

            IF lv_response_status-code <> create-code.
                APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_ERROR'
                                %msg            = new_message_with_text( text     = |{ lv_response_status-code } - { lv_response_status-reason }|
                                severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).

            else.
                """"""""""""""""""""""""HANDLE JSON""""""""""""""""""""""""""""""

                TYPES:
                    BEGIN OF ts_AddressUsage,
                      AddressUsage    TYPE string,
                    END OF ts_AddressUsage,
                    BEGIN OF rs_AddressUsage,
                      results    TYPE STANDARD TABLE OF ts_AddressUsage WITH EMPTY KEY,
                    END OF rs_AddressUsage,
                    BEGIN OF Address_ID,
                      AddressID    TYPE string,
                      to_AddressUsage   TYPE rs_AddressUsage,
                    END OF Address_ID,
                    BEGIN OF BusinessPartnerAddress,
                      results    TYPE STANDARD TABLE OF Address_ID WITH EMPTY KEY,
                    END OF BusinessPartnerAddress,
                    BEGIN OF BusinessPartnerHeader,
                      BusinessPartner    TYPE string,
                      Customer    TYPE string,
                      to_BusinessPartnerAddress TYPE BusinessPartnerAddress,
                    END OF BusinessPartnerHeader,
                    BEGIN OF d_root,
                      d    TYPE BusinessPartnerHeader,
                    END OF d_root.
                     DATA ls_osm TYPE d_root.

                      " Convert the data from JSON to ABAP using the XCO Library; output the data
                    TRY.

                      xco_cp_json=>data->from_string( lv_response )->apply( VALUE #(
                        ( xco_cp_json=>transformation->pascal_case_to_underscore )
                        ( xco_cp_json=>transformation->boolean_to_abap_bool )
                      ) )->write_to( REF #( ls_osm ) ).
                    IF sfrqapi_select-is_contact = 'X' OR sfrqapi_select-is_contact = 'true'.
                        businessPartnerID = ls_osm-d-businesspartner.
                        data(temp) = 'A_BusinessPartner('.
                        IF lv_response CS temp.
                            temp = substring( val = lv_response off = sy-fdpos + 19 len = 7 ).
                            businessPartnerID = temp.
                        ENDIF.
                    else.
                        businessPartnerID = ls_osm-d-customer.
                    ENDIF.
                    LOOP AT ls_osm-d-to_businesspartneraddress-results ASSIGNING FIELD-SYMBOL(<element>).
                        Data: usage type string,
                              addressID type string.

                        addressID = <element>-addressid.
                        Data(usage_rs) = <element>-to_addressusage-results.
                        LOOP AT usage_rs ASSIGNING FIELD-SYMBOL(<element1>).
                            usage = <element1>-addressusage.
                            if usage = 'BILL_TO'.
                                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                                  ENTITY SalesForceRequestAPI
                                    UPDATE FIELDS ( billto_addressid )
                                    WITH VALUE #( (
                                                      %tky       = sfrqapi_select-%tky
                                                      billto_addressid = addressID
                                                    ) ).
                            ENDIF.

                            if usage = 'XXDEFAULT'.
                                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                              ENTITY SalesForceRequestAPI
                                UPDATE FIELDS ( register_addressid )
                                WITH VALUE #( (
                                                  %tky       = sfrqapi_select-%tky
                                                  register_addressid = addressid
                                                ) ).
                            ENDIF.

                            if usage = 'SHIP_TO'.
                                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                                  ENTITY SalesForceRequestAPI
                                    UPDATE FIELDS ( shipto_addressid )
                                    WITH VALUE #( (
                                                      %tky       = sfrqapi_select-%tky
                                                      shipto_addressid = addressid
                                                    ) ).
                            ENDIF.
                         ENDLOOP.
                    ENDLOOP.
                    APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_SUCCESS'
                                %msg            = new_message_with_text( text     = |Business Partner created: { businessPartnerID }|
                               severity    = if_abap_behv_message=>severity-success ) ) TO reported-salesforcerequestapi.

                        MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                          ENTITY SalesForceRequestAPI
                            UPDATE FIELDS ( businesspartnerid api_result )
                            WITH VALUE #( (
                                              %tky       = sfrqapi_select-%tky
                                              businesspartnerid = businessPartnerID
                                              api_result = '200'
                                            ) ).
                " catch any error
                    CATCH cx_root INTO DATA(lx_root).


                    ENDTRY.

            ENDIF.
        ELSE."SOMETHING


        ENDIF.

        ENDLOOP.

        CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error.
            "error handling
        ENDTRY.

        "uncomment the following line for console output; prerequisite: code snippet is implementation of if_oo_adt_classrun~main
        "out->write( |response:  { lv_response }| ).
  ENDMETHOD.

  METHOD updatefirstname.
  ENDMETHOD.

  METHOD ValidateBusinessPartnerID.
    READ ENTITIES OF zi_sfrqapi IN LOCAL MODE
        ENTITY SalesForceRequestAPI
        FIELDS ( salesforceaccountid ) WITH CORRESPONDING #( keys )
        RESULT DATA(sfrqapi_result).
    LOOP AT sfrqapi_result INTO DATA(sfrqapi_select).
        IF sfrqapi_select-api_result = '400'.
            APPEND VALUE #( %tky            = sfrqapi_select-%tky ) TO failed-salesforcerequestapi.
        ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD SetUpdateAuthToken.
    TRY.
        "create http destination by url; API endpoint for API sandbox
      "DATA(pr_keys) = VALUE ZTSFRQAPI( businesspartnerid = KEYS[ 1 ]-businesspartnerid ).

        Data: sucess type if_web_http_response=>http_status,
              notAuth type if_web_http_response=>http_status,
              Update type if_web_http_response=>http_status,
              create type if_web_http_response=>http_status,
              businessPartnerID type string.
        "SET VALUE
        sucess-code = 200.
        create-code = 201.
        Update-code = 204.
        notAuth-code = 401.
        notAuth-reason = 'Unauthorized'.

        READ ENTITIES OF zi_sfrqapi IN LOCAL MODE
        ENTITY SalesForceRequestAPI
        FIELDS ( salesforceaccountid ) WITH CORRESPONDING #( keys )
        RESULT DATA(sfrqapi_result).

        LOOP AT sfrqapi_result INTO DATA(sfrqapi_select).
        IF sfrqapi_select-salesforceaccountid is INITIAL OR sfrqapi_select-salesforceaccountid = ''.
            APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_Salesforce_AccountID'
                                %msg            = new_message_with_text( text     = 'Salesforce AccountID is initial.'
                               severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
           MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).
            return.
        ENDIF.

        IF sfrqapi_select-businesspartnercategory IS NOT INITIAL.
            try.
                data(lo_http_destination) =
                     cl_http_destination_provider=>create_by_url( 'https://my406848-api.s4hana.cloud.sap/sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BusinessPartner?$top=1' ).
              catch cx_http_dest_provider_error.
                "handle exception
            endtry.
            "create HTTP client by destination
            DATA(lo_web_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_http_destination ) .

            "adding headers with API Key for API Sandbox
            DATA(lo_web_http_request) = lo_web_http_client->get_http_request( ).
            lo_web_http_request->set_header_fields( VALUE #(
            (  name = 'Authorization' value = |Basic U0FNTF9CRUFSRVJfQVNTRVJUSU9OOnVOWWNjeE4pUEpiVU16Vmx6dEROaG1peER4dnV3RHFkTXRidUVHNVA=| )
            (  name = 'Accept' value = 'application/json' )
            (  name = 'x-csrf-token' value = 'FETCH' )
             ) ).

            "set request method and execute request
            DATA(lo_web_http_response) = lo_web_http_client->execute( if_web_http_client=>GET ).
            DATA(lv_response_status) = lo_web_http_response->get_status( )."GET RESPONSE STATUS


            IF lv_response_status = notAuth.
                APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_AUTHORIZATION'
                                %msg            = new_message_with_text( text     = '401 Not Unauthorized. Check authToken'
                                                               severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
                sfrqapi_select-api_result = '401 Not Unauthorized. Check authToken'.
                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).
                RETURN.
            ELSEIF lv_response_status-code <> sucess-code.
                APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_ERROR'
                                %msg            = new_message_with_text( text     = |{ lv_response_status-code } - { lv_response_status-reason }|
                                                               severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
                DATA(lv_response_text) = lo_web_http_response->get_text( )."GET RESPONSE STATUS
                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).
                RETURN.

            ENDIF.

            DATA(lv_response_x_csrf_token) = lo_web_http_response->get_header_field( 'x-csrf-token' ).
            DATA(lv_response_cookie_z91) = lo_web_http_response->get_cookie(
                                         i_name = 'SAP_SESSIONID_Z91_080'
*                                         i_path = ``
                                       ).
            DATA(lv_response_cookie_usercontext) = lo_web_http_response->get_cookie(
             i_name = 'sap-usercontext'
*             i_path = ``
            ).
        ENDIF.

        SELECT Count( * ) FROM zi_sfrqapi WHERE salesforceaccountid = @sfrqapi_select-salesforceaccountid INTO @DATA(id_count).

        IF lv_response_x_csrf_token IS NOT INITIAL AND id_count > 0." BUSINESS PARTNER EXSIST


        ELSEIF lv_response_x_csrf_token IS NOT INITIAL AND id_count = 0." BUSINESS PARTNER NOT EXSIST

            try.
                lo_http_destination =
                     cl_http_destination_provider=>create_by_url( 'https://my406848-api.s4hana.cloud.sap/sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BusinessPartner' ).
              catch cx_http_dest_provider_error.
                "handle exception
            endtry.
            "create HTTP client by destination
            lo_web_http_client = cl_web_http_client_manager=>create_by_http_destination( lo_http_destination ) .

            "adding headers with API Key for API Sandbox
            lo_web_http_request = lo_web_http_client->get_http_request( ).
            lo_web_http_request->delete_header_field( 'Authorization').
            lo_web_http_request->delete_header_field( 'Accept').
            lo_web_http_request->delete_header_field( 'x-csrf-token').
            lo_web_http_request->set_header_fields( VALUE #(
            (  name = 'Content-Type' value = 'application/json' )
            (  name = 'Authorization' value = |Basic U0FNTF9CRUFSRVJfQVNTRVJUSU9OOnVOWWNjeE4pUEpiVU16Vmx6dEROaG1peER4dnV3RHFkTXRidUVHNVA=| )
            (  name = 'Accept' value = 'application/json' )
            (  name = 'x-csrf-token' value = |{ lv_response_x_csrf_token }| )
             ) ).
            lo_web_http_request->set_cookie(
              EXPORTING
                i_name    = 'SAP_SESSIONID_Z91_080'
*                i_path    = ``
                i_value   = lv_response_cookie_z91-value
*                i_domain  = ``
*                i_expires = ``
*                i_secure  = 0
*              RECEIVING
*                r_value   =
            ).
            lo_web_http_request->set_cookie(
              EXPORTING
                i_name    = 'sap-usercontext'
*                i_path    = ``
                i_value   = lv_response_cookie_usercontext-value
*                i_domain  = ``
*                i_expires = ``
*                i_secure  = 0
*              RECEIVING
*                r_value   =
            ).
*            CATCH cx_web_message_error.
*            CATCH cx_web_message_error.
            DATA: bodyjson      TYPE string,
                  bill_to       type string,
                  ship_to       type string,
                  regis_to      type string.

            """""""""""""""""""""""""""BILL TO"""""""""""""""""""""""""""""""
            IF sfrqapi_select-billto_country IS NOT INITIAL AND sfrqapi_select-language IS NOT INITIAL.
                "bill_to = bill_to && '{'."1
                bill_to = bill_to && |"PostalCode": "{ sfrqapi_select-billto_postalcode }",|.
                bill_to = bill_to && |"Country": "{ sfrqapi_select-billto_country }",|.
                bill_to = bill_to && |"CityName": "{ sfrqapi_select-billto_cityname }",|.
                bill_to = bill_to && |"Region": "{ sfrqapi_select-billto_state }",|.
                bill_to = bill_to && |"Language": "{ sfrqapi_select-language }",|.
                bill_to = bill_to && |"StreetName": "{ sfrqapi_select-billto_streetname }",|.
                bill_to = bill_to && |"StreetPrefixName": "{ sfrqapi_select-billto_streetprefixname }",|.
                bill_to = bill_to && |"StreetSuffixName": "{ sfrqapi_select-billto_streetsuffixname }",|.
                    bill_to = bill_to && '"to_AddressUsage": {'."2
                    bill_to = bill_to && '"results": ['.        "3
                        bill_to = bill_to && '{'."4
                            bill_to = bill_to && '"AddressUsage": "BILL_TO",'.
                            bill_to = bill_to && '"StandardUsage": false'.
                        bill_to = bill_to && '}'."4
                    bill_to = bill_to && ']'."3
                    bill_to = bill_to && '}'."2

                    IF sfrqapi_select-phonenumber IS NOT INITIAL.
                        bill_to = bill_to && ',"to_PhoneNumber": {'."2
                        bill_to = bill_to && '"results": ['.        "3
                            bill_to = bill_to && '{'."4
                                bill_to = bill_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                                IF sfrqapi_select-isdefaultphonenumber = 'X'.
                                    bill_to = bill_to && |"IsDefaultPhoneNumber": true ,|.
                                else.
                                    bill_to = bill_to && |"IsDefaultPhoneNumber": false ,|.
                                ENDIF.
                                bill_to = bill_to && |"PhoneNumber": "{ sfrqapi_select-phonenumber }"|.
                            bill_to = bill_to && '}'."4
                        bill_to = bill_to && ']'."3
                        bill_to = bill_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-mobilephone IS NOT INITIAL.
                    bill_to = bill_to && ',"to_MobilePhoneNumber": {'."2
                    bill_to = bill_to && '"results": ['.        "3
                        bill_to = bill_to && '{'."4
                            bill_to = bill_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                            IF sfrqapi_select-isdefaultmobilephonenumber = 'X'.
                                bill_to = bill_to && |"IsDefaultPhoneNumber": true ,|.
                            else.
                                bill_to = bill_to && |"IsDefaultPhoneNumber": false ,|.
                            ENDIF.
                            bill_to = bill_to && |"PhoneNumber": "{ sfrqapi_select-mobilephone }"|.
                        bill_to = bill_to && '}'."4
                    bill_to = bill_to && ']'."3
                    bill_to = bill_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-emailaddress IS NOT INITIAL.
                    bill_to = bill_to && ',"to_EmailAddress": {'."2
                    bill_to = bill_to && '"results": ['.        "3
                        bill_to = bill_to && '{'."4
                            bill_to = bill_to && '"IsDefaultEmailAddress": true,'.
                            bill_to = bill_to && |"EmailAddress": "{ sfrqapi_select-emailaddress }"|.
                        bill_to = bill_to && '}'."4
                    bill_to = bill_to && ']'."3
                    bill_to = bill_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-websiteurl IS NOT INITIAL.
                    bill_to = bill_to && ',"to_URLAddress": {'."2
                    bill_to = bill_to && '"results": ['.        "3
                        bill_to = bill_to && '{'."4
                            bill_to = bill_to && '"IsDefaultURLAddress": true,'.
                            bill_to = bill_to && |"WebsiteURL": "{ sfrqapi_select-websiteurl }"|.
                        bill_to = bill_to && '}'."4
                    bill_to = bill_to && ']'."3
                    bill_to = bill_to && '}'."2
                    ENDIF.

                "bill_to = bill_to && '}'."1
            ENDIF.

            """""""""""""""""""""""""SHIP TO"""""""""""""""""""""""""""""""""
            IF sfrqapi_select-shipto_country IS NOT INITIAL AND sfrqapi_select-language IS NOT INITIAL.
                "ship_to = ship_to && '{'."1
                ship_to = ship_to && |"PostalCode": "{ sfrqapi_select-shipto_postalcode }",|.
                ship_to = ship_to && |"Country": "{ sfrqapi_select-shipto_country }",|.
                ship_to = ship_to && |"CityName": "{ sfrqapi_select-shipto_cityname }",|.
                ship_to = ship_to && |"Region": "{ sfrqapi_select-shipto_state }",|.
                ship_to = ship_to && |"Language": "{ sfrqapi_select-language }",|.
                ship_to = ship_to && |"StreetName": "{ sfrqapi_select-shipto_streetname }",|.
                ship_to = ship_to && |"StreetPrefixName": "{ sfrqapi_select-shipto_streetprefixname }",|.
                ship_to = ship_to && |"StreetSuffixName": "{ sfrqapi_select-shipto_streetsuffixname }",|.
                    ship_to = ship_to && '"to_AddressUsage": {'."2
                        ship_to = ship_to && '"results": ['.        "3
                        ship_to = ship_to && '{'."4
                            ship_to = ship_to && '"AddressUsage": "SHIP_TO",'.
                            ship_to = ship_to && '"StandardUsage": false'.
                        ship_to = ship_to && '}'."4
                        ship_to = ship_to && ']'."3
                    ship_to = ship_to && '}'."2

                    IF sfrqapi_select-phonenumber IS NOT INITIAL.
                        ship_to = ship_to && ',"to_PhoneNumber": {'."2
                        ship_to = ship_to && '"results": ['.        "3
                            ship_to = ship_to && '{'."4
                                ship_to = ship_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                                "ship_to = ship_to && |"IsDefaultPhoneNumber":{ sfrqapi_select-isdefaultphonenumber } ,|.
                                IF sfrqapi_select-isdefaultmobilephonenumber = 'X'.
                                    ship_to = ship_to && |"IsDefaultPhoneNumber": true ,|.
                                else.
                                    ship_to = ship_to && |"IsDefaultPhoneNumber": false ,|.
                                ENDIF.
                                ship_to = ship_to && |"PhoneNumber": "{ sfrqapi_select-phonenumber }"|.
                            ship_to = ship_to && '}'."4
                        ship_to = ship_to && ']'."3
                        ship_to = ship_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-mobilephone IS NOT INITIAL.
                    ship_to = ship_to && ',"to_MobilePhoneNumber": {'."2
                    ship_to = ship_to && '"results": ['.        "3
                        ship_to = ship_to && '{'."4
                            ship_to = ship_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                            "ship_to = ship_to && |"IsDefaultPhoneNumber": { sfrqapi_select-isdefaultmobilephonenumber },|.
                            IF sfrqapi_select-isdefaultmobilephonenumber = 'X'.
                                ship_to = ship_to && |"IsDefaultPhoneNumber": true ,|.
                            else.
                                ship_to = ship_to && |"IsDefaultPhoneNumber": false ,|.
                            ENDIF.
                            ship_to = ship_to && |"PhoneNumber": "{ sfrqapi_select-mobilephone }"|.
                        ship_to = ship_to && '}'."4
                    ship_to = ship_to && ']'."3
                    ship_to = ship_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-emailaddress IS NOT INITIAL.
                    ship_to = ship_to && ',"to_EmailAddress": {'."2
                    ship_to = ship_to && '"results": ['.        "3
                        ship_to = ship_to && '{'."4
                            ship_to = ship_to && '"IsDefaultEmailAddress": true,'.
                            ship_to = ship_to && |"EmailAddress": "{ sfrqapi_select-emailaddress }"|.
                        ship_to = ship_to && '}'."4
                    ship_to = ship_to && ']'."3
                    ship_to = ship_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-websiteurl IS NOT INITIAL.
                    ship_to = ship_to && ',"to_URLAddress": {'."2
                    ship_to = ship_to && '"results": ['.        "3
                        ship_to = ship_to && '{'."4
                            ship_to = ship_to && '"IsDefaultURLAddress": true,'.
                            ship_to = ship_to && |"WebsiteURL": "{ sfrqapi_select-websiteurl }"|.
                        ship_to = ship_to && '}'."4
                    ship_to = ship_to && ']'."3
                    ship_to = ship_to && '}'."2
                    ENDIF.

                "ship_to = ship_to && '}'."1
            ENDIF.

            """"""""""""""""""""""""""""REGISTER TO""""""""""""""""""""""""""""""
            IF sfrqapi_select-register_country IS NOT INITIAL AND sfrqapi_select-language IS NOT INITIAL.
                "regis_to = regis_to && '{'."1
                regis_to = regis_to && |"PostalCode": "{ sfrqapi_select-register_postalcode }",|.
                regis_to = regis_to && |"Country": "{ sfrqapi_select-register_country }",|.
                regis_to = regis_to && |"CityName": "{ sfrqapi_select-register_cityname }",|.
                regis_to = regis_to && |"Region": "{ sfrqapi_select-register_state }",|.
                regis_to = regis_to && |"Language": "{ sfrqapi_select-language }",|.
                regis_to = regis_to && |"StreetName": "{ sfrqapi_select-register_streetname }",|.
                regis_to = regis_to && |"StreetPrefixName": "{ sfrqapi_select-register_streetprefixname }",|.
                regis_to = regis_to && |"StreetSuffixName": "{ sfrqapi_select-register_streetsuffixname }",|.
                    regis_to = regis_to && '"to_AddressUsage": {'."2
                        regis_to = regis_to && '"results": ['.        "3
                        regis_to = regis_to && '{'."4
                            regis_to = regis_to && '"AddressUsage": "XXDEFAULT",'.
                            regis_to = regis_to && '"StandardUsage": false'.
                        regis_to = regis_to && '}'."4
                    regis_to = regis_to && ']'."3
                    regis_to = regis_to && '}'."2

                    IF sfrqapi_select-phonenumber IS NOT INITIAL.
                        regis_to = regis_to && ',"to_PhoneNumber": {'."2
                        regis_to = regis_to && '"results": ['.        "3
                            regis_to = regis_to && '{'."4
                                regis_to = regis_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                                "regis_to = regis_to && |"IsDefaultPhoneNumber": { sfrqapi_select-isdefaultphonenumber },|.
                                IF sfrqapi_select-isdefaultphonenumber = 'X'.
                                    regis_to = regis_to && |"IsDefaultPhoneNumber": true ,|.
                                else.
                                    regis_to = regis_to && |"IsDefaultPhoneNumber": false ,|.
                                ENDIF.
                                regis_to = regis_to && |"PhoneNumber": "{ sfrqapi_select-phonenumber }"|.
                            regis_to = regis_to && '}'."4
                        regis_to = regis_to && ']'."3
                        regis_to = regis_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-mobilephone IS NOT INITIAL.
                    regis_to = regis_to && ',"to_MobilePhoneNumber": {'."2
                    regis_to = regis_to && '"results": ['.        "3
                        regis_to = regis_to && '{'."4
                            regis_to = regis_to && |"DestinationLocationCountry": "{ sfrqapi_select-destinationlocationcountry }",|.
                            "regis_to = regis_to && |"IsDefaultPhoneNumber": { sfrqapi_select-isdefaultmobilephonenumber },|.
                            IF sfrqapi_select-isdefaultmobilephonenumber = 'X'.
                                regis_to = regis_to && |"IsDefaultPhoneNumber": true ,|.
                            else.
                                regis_to = regis_to && |"IsDefaultPhoneNumber": false ,|.
                            ENDIF.
                            regis_to = regis_to && |"PhoneNumber": "{ sfrqapi_select-mobilephone }"|.
                        regis_to = regis_to && '}'."4
                    regis_to = regis_to && ']'."3
                    regis_to = regis_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-emailaddress IS NOT INITIAL.
                    regis_to = regis_to && ',"to_EmailAddress": {'."2
                    regis_to = regis_to && '"results": ['.        "3
                        regis_to = regis_to && '{'."4
                            regis_to = regis_to && '"IsDefaultEmailAddress": true,'.
                            regis_to = regis_to && |"EmailAddress": "{ sfrqapi_select-emailaddress }"|.
                        regis_to = regis_to && '}'."4
                    regis_to = regis_to && ']'."3
                    regis_to = regis_to && '}'."2
                    ENDIF.

                    IF sfrqapi_select-websiteurl IS NOT INITIAL.
                    regis_to = regis_to && ',"to_URLAddress": {'."2
                    regis_to = regis_to && '"results": ['.        "3
                        regis_to = regis_to && '{'."4
                            regis_to = regis_to && '"IsDefaultURLAddress": true,'.
                            regis_to = regis_to && |"WebsiteURL": "{ sfrqapi_select-websiteurl }"|.
                        regis_to = regis_to && '}'."4
                    regis_to = regis_to && ']'."3
                    regis_to = regis_to && '}'."2
                    ENDIF.

                "regis_to = regis_to && '}'."1
           ENDIF.

            """"""""""""""""""""""""""""""BODY REQUEST"""""""""""""""""""""""""""""
            bodyjson = '{'."Header
            "bodyjson = bodyjson && |"BusinessPartner":"{ sfrqapi_select-businesspartnerid }",|.
            bodyjson = bodyjson && |"BusinessPartnerCategory": "{ sfrqapi_select-businesspartnercategory }",|.


            IF sfrqapi_select-yy1_fatca_1_bus = 'X'.

                bodyjson = bodyjson && |"YY1_FATCA_1_bus": true,|.
            ELSE.
                bodyjson = bodyjson && '"YY1_FATCA_1_bus": false,'.
            ENDIF.

            IF regis_to IS INITIAL AND ship_to IS INITIAL AND bill_to IS INITIAL.
                APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_ADDRESS'
                                %msg            = new_message_with_text( text     = 'Address Country Or Language is null'
                                severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).
                RETURN.
            ENDIF.

            bodyjson = bodyjson && '"to_BusinessPartnerAddress": {'."to_BusinessPartnerAddress
                bodyjson = bodyjson && '"results": ['."1
                IF regis_to IS NOT INITIAL.
                    bodyjson = bodyjson && '{'.
                    bodyjson = bodyjson && regis_to.
                    bodyjson = bodyjson && '},'.
                ENDIF.

                IF ship_to IS NOT INITIAL.
                    bodyjson = bodyjson && '{'.
                    bodyjson = bodyjson && ship_to.
                    bodyjson = bodyjson && '},'.
                ENDIF.

                IF bill_to IS NOT INITIAL.
                    bodyjson = bodyjson && '{'.
                    bodyjson = bodyjson && bill_to.
                    bodyjson = bodyjson && '},'.
                ENDIF.
                bodyjson = shift_right( val = bodyjson places = 1 ).
                bodyjson = bodyjson && ']'."1
            bodyjson = bodyjson && '},'."to_BusinessPartnerAddress

            IF sfrqapi_select-is_contact = 'X' OR sfrqapi_select-is_contact = 'true'.
                bodyjson = bodyjson && |"FirstName": "{ sfrqapi_select-firstname }",|.
                bodyjson = bodyjson && |"LastName": "{ sfrqapi_select-lastname }",|.
                bodyjson = bodyjson && '"to_BusinessPartnerRole": {'."to_BusinessPartnerRole
                    bodyjson = bodyjson && '"results": ['."1
                        bodyjson = bodyjson && '{'."2
                            bodyjson = bodyjson && '"BusinessPartnerRole": "BUP001"'.
                        bodyjson = bodyjson && '}'."2
                    bodyjson = bodyjson && ']'."1
                bodyjson = bodyjson && '}'."to_BusinessPartnerRole

            ELSE.
                bodyjson = bodyjson && |"OrganizationBPName1": "{ sfrqapi_select-organizationbpname1 }",|.
                bodyjson = bodyjson && '"to_BusinessPartnerRole": {'."to_BusinessPartnerRole
                    bodyjson = bodyjson && '"results": ['."1
                        bodyjson = bodyjson && '{'."2
                            bodyjson = bodyjson && '"BusinessPartnerRole": "FLCU00"'.
                        bodyjson = bodyjson && '},'."2
                        bodyjson = bodyjson && '{'."3
                            bodyjson = bodyjson && '"BusinessPartnerRole": "FLCU01"'.
                        bodyjson = bodyjson && '}'."3
                    bodyjson = bodyjson && ']'."1
                bodyjson = bodyjson && '},'."to_BusinessPartnerRole


                IF sfrqapi_select-industrysector <> '' AND sfrqapi_select-industrysystemtype <> ''.
                    bodyjson = bodyjson && '"to_BuPaIndustry": {'."to_BuPaIndustry
                        bodyjson = bodyjson && '"results": ['."1
                            bodyjson = bodyjson && '{'."2
                                bodyjson = bodyjson && |"IndustrySector": "{ sfrqapi_select-industrysector }",|.
                                bodyjson = bodyjson && |"IndustrySystemType": "{ sfrqapi_select-industrysystemtype }"|.
                            bodyjson = bodyjson && '}'."2
                        bodyjson = bodyjson && ']'."1
                    bodyjson = bodyjson && '},'."to_BuPaIndustry
                ENDIF.

                bodyjson = bodyjson && '"to_Customer": {'."Customer
                    bodyjson = bodyjson && |"CustomerClassification": "{ sfrqapi_select-customerclassification }",|.
                    bodyjson = bodyjson && '"to_CustomerText": {'."1
                        bodyjson = bodyjson && '"results": ['."2
                            bodyjson = bodyjson && '{'."3
                                bodyjson = bodyjson && '"Language": "VI",'.
                                bodyjson = bodyjson && '"LongTextID": "TX01",'.
                                bodyjson = bodyjson && |"LongText": "{ sfrqapi_select-text }"|.
                            bodyjson = bodyjson && '}'."3
                        bodyjson = bodyjson && ']'."2
                    bodyjson = bodyjson && '},'."1

                    bodyjson = bodyjson && '"to_CustomerSalesArea": {'."1
                        bodyjson = bodyjson && '"results": ['."2
                            bodyjson = bodyjson && '{'."3
                                bodyjson = bodyjson && |"SalesOrganization": "{ sfrqapi_select-salesorganization }",|.
                                bodyjson = bodyjson && |"DistributionChannel": "{ sfrqapi_select-distributionchannel }",|.
                                bodyjson = bodyjson && |"Division": "{ sfrqapi_select-division }",|.
                                bodyjson = bodyjson && |"Currency": "{ sfrqapi_select-currency }",|.
                                bodyjson = bodyjson && '"to_SalesAreaTax": {'."4
                                    bodyjson = bodyjson && '"results": ['."5
                                        bodyjson = bodyjson && '{'."6
                                            bodyjson = bodyjson && '"CustomerTaxCategory": "TTX1",'.
                                            bodyjson = bodyjson && |"CustomerTaxClassification": "{ sfrqapi_select-customertaxclassification }"|.
                                        bodyjson = bodyjson && '}'."6
                                    bodyjson = bodyjson && ']'."5
                                bodyjson = bodyjson && '}'."4
                            bodyjson = bodyjson && '}'."3
                        bodyjson = bodyjson && ']'."2
                    bodyjson = bodyjson && '},'."1

                    bodyjson = bodyjson && '"to_CustomerCompany": {'."1
                        bodyjson = bodyjson && '"results": ['."2
                            bodyjson = bodyjson && '{'."3
                                bodyjson = bodyjson && |"CompanyCode": "{ sfrqapi_select-companycode }",|.
                                bodyjson = bodyjson && |"ReconciliationAccount": "{ sfrqapi_select-reconciliationaccount }",|.
                                bodyjson = bodyjson && |"PaymentTerms": "{ sfrqapi_select-paymentterms }"|.
                            bodyjson = bodyjson && '}'."3
                        bodyjson = bodyjson && ']'."2
                    bodyjson = bodyjson && '}'."1
                bodyjson = bodyjson && '}'."Customer
            ENDIF.
            bodyjson = bodyjson && '}'.

            "set request method and execute request

            lo_web_http_request->set_text( bodyjson ).

            lo_web_http_response = lo_web_http_client->execute( if_web_http_client=>POST ).

            lv_response_status = lo_web_http_response->get_status( )."GET RESPONSE STATUS
            DATA(lv_response) = lo_web_http_response->get_text( ).

            IF lv_response_status-code <> create-code.
                APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_ERROR'
                                %msg            = new_message_with_text( text     = |{ lv_response_status-code } - { lv_response_status-reason }|
                                severity    = if_abap_behv_message=>severity-error ) ) TO reported-salesforcerequestapi.
                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                  ENTITY SalesForceRequestAPI
                    UPDATE FIELDS ( businesspartnerid api_result )
                    WITH VALUE #( (
                                      %tky       = sfrqapi_select-%tky
                                      api_result = '400'
                                    ) ).

            else.
                """"""""""""""""""""""""HANDLE JSON""""""""""""""""""""""""""""""

                TYPES:
                    BEGIN OF ts_AddressUsage,
                      AddressUsage    TYPE string,
                    END OF ts_AddressUsage,
                    BEGIN OF rs_AddressUsage,
                      results    TYPE STANDARD TABLE OF ts_AddressUsage WITH EMPTY KEY,
                    END OF rs_AddressUsage,
                    BEGIN OF Address_ID,
                      AddressID    TYPE string,
                      to_AddressUsage   TYPE rs_AddressUsage,
                    END OF Address_ID,
                    BEGIN OF BusinessPartnerAddress,
                      results    TYPE STANDARD TABLE OF Address_ID WITH EMPTY KEY,
                    END OF BusinessPartnerAddress,
                    BEGIN OF BusinessPartnerHeader,
                      BusinessPartner    TYPE string,
                      Customer    TYPE string,
                      to_BusinessPartnerAddress TYPE BusinessPartnerAddress,
                    END OF BusinessPartnerHeader,
                    BEGIN OF d_root,
                      d    TYPE BusinessPartnerHeader,
                    END OF d_root.
                     DATA ls_osm TYPE d_root.

                      " Convert the data from JSON to ABAP using the XCO Library; output the data
                    TRY.

                      xco_cp_json=>data->from_string( lv_response )->apply( VALUE #(
                        ( xco_cp_json=>transformation->pascal_case_to_underscore )
                        ( xco_cp_json=>transformation->boolean_to_abap_bool )
                      ) )->write_to( REF #( ls_osm ) ).
                    IF sfrqapi_select-is_contact = 'X' OR sfrqapi_select-is_contact = 'true'.
                        businessPartnerID = ls_osm-d-businesspartner.
                        data(temp) = 'A_BusinessPartner('.
                        IF lv_response CS temp.
                            temp = substring( val = lv_response off = sy-fdpos + 19 len = 7 ).
                            businessPartnerID = temp.
                        ENDIF.
                    else.
                        businessPartnerID = ls_osm-d-customer.
                    ENDIF.
                    LOOP AT ls_osm-d-to_businesspartneraddress-results ASSIGNING FIELD-SYMBOL(<element>).
                        Data: usage type string,
                              addressID type string.

                        addressID = <element>-addressid.
                        Data(usage_rs) = <element>-to_addressusage-results.
                        LOOP AT usage_rs ASSIGNING FIELD-SYMBOL(<element1>).
                            usage = <element1>-addressusage.
                            if usage = 'BILL_TO'.
                                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                                  ENTITY SalesForceRequestAPI
                                    UPDATE FIELDS ( billto_addressid )
                                    WITH VALUE #( (
                                                      %tky       = sfrqapi_select-%tky
                                                      billto_addressid = addressID
                                                    ) ).
                            ENDIF.

                            if usage = 'XXDEFAULT'.
                                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                              ENTITY SalesForceRequestAPI
                                UPDATE FIELDS ( register_addressid )
                                WITH VALUE #( (
                                                  %tky       = sfrqapi_select-%tky
                                                  register_addressid = addressid
                                                ) ).
                            ENDIF.

                            if usage = 'SHIP_TO'.
                                MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                                  ENTITY SalesForceRequestAPI
                                    UPDATE FIELDS ( shipto_addressid )
                                    WITH VALUE #( (
                                                      %tky       = sfrqapi_select-%tky
                                                      shipto_addressid = addressid
                                                    ) ).
                            ENDIF.
                         ENDLOOP.
                    ENDLOOP.
                    APPEND VALUE #( %tky            = sfrqapi_select-%tky
                                %state_area     = 'VALIDATE_SUCCESS'
                                %msg            = new_message_with_text( text     = |Business Partner created: { businessPartnerID }|
                               severity    = if_abap_behv_message=>severity-success ) ) TO reported-salesforcerequestapi.

                        MODIFY ENTITIES OF zi_sfrqapi IN LOCAL MODE
                          ENTITY SalesForceRequestAPI
                            UPDATE FIELDS ( businesspartnerid api_result )
                            WITH VALUE #( (
                                              %tky       = sfrqapi_select-%tky
                                              businesspartnerid = businessPartnerID
                                              api_result = '200'
                                            ) ).
                " catch any error
                    CATCH cx_root INTO DATA(lx_root).


                    ENDTRY.

            ENDIF.
        ELSE."SOMETHING


        ENDIF.

        ENDLOOP.

        CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error.
            "error handling
        ENDTRY.

        "uncomment the following line for console output; prerequisite: code snippet is implementation of if_oo_adt_classrun~main
        "out->write( |response:  { lv_response }| ).
  ENDMETHOD.

ENDCLASS.
