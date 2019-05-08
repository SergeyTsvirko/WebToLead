public class ConfirmRegistrationComponentController {
    public String docName { get; set; }
    
    public String getDocumentUrl()
    {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://safe-fortress-52401.herokuapp.com/' + docName);
        request.setMethod('GET');
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == 200) {
            return response.getBody();
        } else {
            return 'Error ' + response.getStatusCode();
        }
    }
}