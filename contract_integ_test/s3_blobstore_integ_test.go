package main_test

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	yaml "gopkg.in/yaml.v2"

	"os"

	"github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo"
	"github.com/onsi/gomega"
	. "github.com/onsi/gomega"
	. "github.com/petergtz/bitsgo/s3_blobstore"
)

type S3BlobstoreConfig struct {
	Bucket          string
	AccessKeyID     string `yaml:"access_key_id"`
	SecretAccessKey string `yaml:"secret_access_key"`
}

func TestS3Blobstore(t *testing.T) {
	gomega.RegisterFailHandler(ginkgo.Fail)
	ginkgo.RunSpecs(t, "S3Blobstore Integration")
}

var _ = Describe("S3 Blobstores", func() {
	var (
		config   S3BlobstoreConfig
		filepath string
	)

	BeforeEach(func() {
		filename := os.Getenv("CONFIG")
		if filename == "" {
			fmt.Println("No $CONFIG set. Defaulting to integration_test_config.yml")
			filename = "integration_test_config.yml"
		}
		file, e := os.Open(filename)
		Expect(e).NotTo(HaveOccurred())
		defer file.Close()
		content, e := ioutil.ReadAll(file)
		Expect(e).NotTo(HaveOccurred())
		e = yaml.Unmarshal(content, &config)
		Expect(e).NotTo(HaveOccurred())
		Expect(config.Bucket).NotTo(BeEmpty())
		Expect(config.AccessKeyID).NotTo(BeEmpty())
		Expect(config.SecretAccessKey).NotTo(BeEmpty())

		filepath = fmt.Sprintf("testfile-%v", time.Now())
	})

	Describe("S3LegacyBlobstore", func() {
		It("can put and get a resource there", func() {
			blobstore := NewS3LegacyBlobstore(config.Bucket, config.AccessKeyID, config.SecretAccessKey)

			// Put:
			responseWriter := httptest.NewRecorder()
			blobstore.Put(filepath, strings.NewReader("the file content"), responseWriter)
			Expect(responseWriter.Code).To(Equal(http.StatusCreated))

			// Get:
			responseWriter = httptest.NewRecorder()
			blobstore.Get(filepath, responseWriter)
			Expect(responseWriter.Code).To(Equal(http.StatusFound))

			// Follow redirect:
			response, e := http.Get(responseWriter.Header().Get("location"))
			Expect(e).NotTo(HaveOccurred())
			Expect(ioutil.ReadAll(response.Body)).To(MatchRegexp("the file content"))
		})
	})

	Describe("S3PureRedirectBlobstore", func() {
		It("can put and get a resource there", func() {
			blobstore := NewS3PureRedirectBlobstore(config.Bucket, config.AccessKeyID, config.SecretAccessKey)

			// Put:
			responseWriter := httptest.NewRecorder()
			blobstore.Put(filepath, nil, responseWriter)
			Expect(responseWriter.Code).To(Equal(http.StatusFound))

			// Follow redirect:
			request, e := http.NewRequest("PUT", responseWriter.Header().Get("location"), strings.NewReader("the file content"))
			Expect(e).NotTo(HaveOccurred())
			response, e := http.DefaultClient.Do(request)
			Expect(e).NotTo(HaveOccurred())
			Expect(response.StatusCode).To(Equal(http.StatusOK))

			// Get:
			responseWriter = httptest.NewRecorder()
			blobstore.Get(filepath, responseWriter)
			Expect(responseWriter.Code).To(Equal(http.StatusFound))

			// Follow redirect:
			response, e = http.Get(responseWriter.Header().Get("location"))
			Expect(e).NotTo(HaveOccurred())
			Expect(ioutil.ReadAll(response.Body)).To(MatchRegexp("the file content"))
		})
	})
})