package bitsgo

import (
	"fmt"
	"net/http"
	"time"

	"github.com/benbjohnson/clock"
)

type ResourceSigner interface {
	Sign(resource string, method string, expirationTime time.Time) (signedURL string)
}

type SignResourceHandler struct {
	signer ResourceSigner
	clock  clock.Clock
}

func NewSignResourceHandler(signer ResourceSigner) *SignResourceHandler {
	return &SignResourceHandler{
		signer: signer,
		clock:  clock.New(),
	}
}

func (handler *SignResourceHandler) Sign(responseWriter http.ResponseWriter, request *http.Request, params map[string]string) {
	method := request.URL.Query().Get("verb")
	if method == "" {
		method = "get"
	}
	fmt.Fprint(responseWriter, handler.signer.Sign(params["resource"], method, handler.clock.Now().Add(1*time.Hour)))
}
