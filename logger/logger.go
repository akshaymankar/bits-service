package logger

import (
	"github.com/uber-go/zap"
)

var Log = zap.New(zap.NewTextEncoder(), zap.DebugLevel, zap.AddCaller())
