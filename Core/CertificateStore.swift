import Foundation
import Security

struct CertificateStore {

    static let p12Base64 = "MIIJ7wIBAzCCCaUGCSqGSIb3DQEHAaCCCZYEggmSMIIJjjCCA/oGCSqGSIb3DQEHBqCCA+swggPnAgEAMIID4AYJKoZIhvcNAQcBMF8GCSqGSIb3DQEFDTBSMDEGCSqGSIb3DQEFDDAkBBDoeN6Ah6/2lEBVTkuCya2mAgIIADAMBggqhkiG9w0CCQUAMB0GCWCGSAFlAwQBKgQQEioodDK/WnAT/Tly5khkiYCCA3DLWs37f6bENo/D6WDn824K7t9nkrQCEij9vcjW7+nKnR1Khra66fiu5cwTKQFpWd4rhggecVQM9yxODmvU5RFvffj/o3jMGqCLTrzTDgqchLhj2Lql6/jknE4a0eyKa+5PxsQTc9P8A42SVkmrJdzbK1wRQG0j5BwdY6OFKgLfK+ROOJnBubj7Jf4eUJSGkSU6587QEk5Z1var9ScN2eZRqPZ8Vc3Ug4HIMr0GMx3PptZDiZyV942lBcREY4BvzyvM1A53FEiyOWpRDMF1R/QoD9qYJ7Mzk/sROOvAaJtIWRK61vH7UVMA/jVKp++/B7dGHP11E+df5QlPKOLKDHPDUzTlEngPdQltnwtZf9PAWpeDBdAgDw7dShqRyilK/6AViptnMEAtlh77QG4ojnixGe0d2SetQaHmXX9iLWrpEMhONpqOiWw6/w2TMP4De3AqJAh3p3HWQ/HaPyucKqp9DOzxng93UQjBzGWRUB54kX0vkUKxy9Ur+jRRk1BLkHw6xVpX5/SLVEWbRcHMoebYecnIcPfumdhkMveLQkLABFLishZyWJ5nYCesvE3V2MB2C23O7ulx3+wnZ84zjpiaPW76mF6YkSzI3BfDqifzbt1gjdUgQ6/47CkJDPbF5ERP9Jd1IOvz+YyF8wb/iudg4xph9AQAFtgWRqlQxB93G3yhIlyV3ZBDht985v//ja0MeGWI8YVGDW5G7EZDLjf+sBlYGRZ+M/pir4wzMsOUwmZx+IhYsJuCDPduxC8q5XoT0NojZlss/Udr1yoqwY54jFxRm3dbBhn54JdMX4h+5THiMLhkpNzCOeypKQMDjNAiuYrnFX/aqRyIctyVoX1e5QWJV98fHEPt0EzWocysQGsLtL15SZlSiBxNlOpWwEkbgRIHw4VRAVg2kI4P+kp1VN3lW3SbYQO0QUkMNyLqlaYwiShq4Eu9gVVYdULDNF0mtNp0zodc4qn1kBl6i8J7yIF2jF/KyhYzTX4xxQiVD0BY8Ywn+lQar70SbFHuxHkm7hvuPQCHCcCjFl5ACCb+6qIYYTwivLxh+5IFXmBiwgMJO9lOH/AVprf4CcbdLgr7oEmm4CRfFzc3CVBn5xDBalBnpyI7EEDJ8nP9cDWkrJ3YqdqBfCenQjD3lOtOep+FofZ4BrcRCOewiaMAZMVEMIIFjAYJKoZIhvcNAQcBoIIFfQSCBXkwggV1MIIFcQYLKoZIhvcNAQwKAQKgggU5MIIFNTBfBgkqhkiG9w0BBQ0wUjAxBgkqhkiG9w0BBQwwJAQQMy8yq+aXZcOhFjuHIIRw6gICCAAwDAYIKoZIhvcNAgkFADAdBglghkgBZQMEASoEEIJqNx58zuDlir2LKOrfOvsEggTQ8rqerkqYidpZNxPTcij+2LIAUlV8UbiS4hNdIVeleE8m6XtBysNZeWlExfFynNUkSy+y+e6C4VhWf/NW7i6O7TI+5ayycfdjba1NNiCnxvZqS5ai6Y9qcyEFhrm8vHm/sXZST77iihLDqzwrU/B0INWCqRwlQrJft3NY52cHQpUKjI6PSG4lfM2H7aEY4qWxyoKZZpaVftJdrcUS14Q1bOOOkU0692Eh4oHHlu79SdpAafuqCW6JsCIsc3wzdJBDbLAu2kEelmGsWxmIZfcKMcslRTYEeGVVO0zQuYMy4wx84gtwomkS3e3/C4HNh1BXyTThHE1Y8PwVUdSV6fstGriLTpN8kStdYHhnHo1hds0nfEHHqipe+qJugkg9baFpVC5ulSUI6KG3TfyKtZMc9HCy0ZJBll68utYKq5RLimnM7pxIQO+92ayZMlT+BJ7hSnhImF70gqyfhF0nCRiZ74NBpGaYnWD9NcBLjNXtMU1OvkUVcy1njbXC+sM8ua0kr74FG/LtNgHxxeM5xn++Cu0uEZWwmQoF0wiUafaQ4R3vFVisizMAyhSY8IkLYKt58CIRqVbU2UOkMc+rfcKyBd4zlrohts3/bYlMdO2xf9VYZgRMu7WN4j67ZCC9KPi0BQlZNfFlD7woX96o+OCJKTsz/DK8atpH8LnuNgsF0C1pZmaz7NxMtg8llF4bce/Ftl9kya05phKWzn4lyUSQn20efZuGv/NWnKZwGJtlNm51KgexqQGG5bWuJpUTWylyyFGgsuVPfrLPBd6UY1YVKAmn5XvYOlGWCmk96jg8SloisLkrDEJ1xAvwMDFcjgBNT7t5tB8Ood22F9FIFxqoCsS9IXsoY/szR3ZzIrf22DuhcbdlNtfAhytqRdQcdZbhl/uZUG81h6sovUWnzr8nOR/PaTszllmd16e5mOaMkeavCXHV5wTRIksge7RXWVaTNSmDr7wNcA81VSWvO2cpbeLGVZ+mHc6tcxM4vykR85/x78qv53TvnD9FQuA2y3ekzSSsOE81lg/BKF51YALcQUEY4uUTpk2u6BM7FqhQGibHWJx3ZYaQKwaB0mF6YyI8E+h0hDLEZrI5bl8DFoMc8bE1OJ1/qWxaYn4K6iqbKeQksVuPuSzLZqXnBmVGmDhpsla+WtlN+Qt+I0+DZgZlEQHhGhtwmLwtvGN/q/gJtrTHEXOUFs7Ml2uueg1QtYZ0mxn85AFgpqTUapGXs763iQhpp7XwhKpSy04P8WZgxZ8rc2yfH0tR7kNoG+bh1duX/B7/anksRq/hu4arAhmm7f/LYBBpoKkfMtQOvVnehozyaW6N/eegmVlepRwUl0kXq0moImlICiY0xvHbcN6Z2aWYJw1W4PHdFhFedgGZHlrokSah2+GMPurKq17KaeJKsC3CbnoNaMaVqtsI+cz7NvSiE7qwP/8oiirJcJKbuoyLUhpEpDrh3Vu12YMJRTb/xJ5okbTYH0y46Dr9msvkHjIQKCMV+3RIm6vSjyQm+x5lPwJozDWe11iT7+GtMom5NXs1XRZ18bjnU3JUkqG09caZp1h7RWleALGEZJKKiFjTohJrNHsrv/GuiKDxB8we2NXeh33UMW6dHe4nLoYwm0pVi5Ymma+x2ZX0EFOM4ysxJTAjBgkqhkiG9w0BCRUxFgQUCL7B02r68KWx19sidH9SjnMi4EgwQTAxMA0GCWCGSAFlAwQCAQUABCCl4xiGQjO5mX61+K3k2T0ilrWLL9owOGfKMVFknNchAwQIrWiVN8f2ToYCAggA"
    static let password = "remotetv"

    static func getClientIdentity() -> SecIdentity? {
        guard let data = Data(base64Encoded: p12Base64) else {
            print("[CertStore] Error decodificando Base64 de PKCS12")
            return nil
        }

        // NSDictionary evita el cast [String:Any] as CFDictionary que falla en Swift 5
        let options = NSDictionary(object: password, forKey: kSecImportExportPassphrase as NSString)

        var rawItems: CFArray?
        let status = SecPKCS12Import(data as CFData, options, &rawItems)

        guard status == errSecSuccess,
              let items = rawItems as? [[String: Any]],
              let firstItem = items.first else {
            print("[CertStore] Error en SecPKCS12Import: \(status)")
            return nil
        }

        if let rawIdentity = firstItem[kSecImportItemIdentity as String] {
            return (rawIdentity as! SecIdentity)
        }
        return nil
    }
}
