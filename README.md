# nim.yawd
Yet another webdriver (YAWD) for nim language - https://www.w3.org/TR/webdriver/

### install
```
nimble install https://github.com/zendbit/nim.yawd.git
```
or via nimble directory
```
nimble install yawd
```

### example
```nim
import yawd

let webDriver = newWebDriver(host = "127.0.0.1", port = 9515)

##	create new session
let sessionWD = (waitFor webDriver.newSession(%*{
	"user": "tester",
	"password": "tester",
	"capabilities": {
		"firstMatch": [
			{
				"browserName": "chrome",
				"platformName": "linux"
			}
		]
	}
}))

echo sessionWD.pretty
echo waitFor webDriver.getStatus
	
var responseMsg = waitFor webDriver.getTimeouts()
#echo waitFor webDriver.setTimeouts(script = 40000)
#echo waitFor webDriver.getTimeouts()

echo waitFor webDriver.navigateTo("https://techcrunch.com")
echo waitFor webDriver.getCurrentUrl()
echo waitFor webDriver.back()
echo waitFor webDriver.forward()
echo waitFor webDriver.refresh()
echo waitFor webDriver.getTitle()
responseMsg = waitFor webDriver.getWindowHandle()
echo waitFor webDriver.switchToWindow(responseMsg{"data"}{"value"}.getStr)
responseMsg = waitFor webDriver.newWindow()
echo waitFor webDriver.switchToWindow(responseMsg{"data"}{"value"}{"handle"}.getStr)
echo waitFor webDriver.navigateTo("https://google.com")
echo waitFor webDriver.getTitle()
echo waitFor webDriver.getWindowHandles()
echo waitFor webDriver.switchToFrame(0)
echo waitFor webDriver.switchToParentFrame()
echo waitFor webDriver.getWindowRect()
echo waitFor webDriver.setWindowRect(width = 800, height = 600)
echo waitFor webDriver.fullscreenWindow()
echo waitFor webDriver.minimizeWindow()
echo waitFor webDriver.maximizeWindow()
responseMsg = waitFor webDriver.findElement("""//input[@name="q"]""", LocationElementStrategyType.XPathSelector)
echo waitFor webDriver.elementSendKeys(responseMsg{"data"}{"value"}{$ContextIdentifierType.ElementIdentifier}.getStr, "nim programming language")
echo waitFor webDriver.getPageSource()
echo waitFor webDriver.executeScript("""alert("Hello World");""")
echo waitFor webDriver.getNamedCookie("NID")
echo waitFor webDriver.addCookie(name = "Test", value = "test")
echo waitFor webDriver.getAllCookies()
echo waitFor webDriver.deleteCookie("Test")
echo waitFor webDriver.refresh()
echo waitFor webDriver.getAllCookies()

##	Test action
var actions: seq[JsonNode]

var scrollAction = newAction[ScrollAction]("wheel")
scrollAction.actions.add(newScrollAction(deltaX = 500, deltaY = 500))
actions.add(%scrollAction)

echo actions
echo waitFor webDriver.performActions(actions)

echo waitFor webDriver.closeWindow()
echo waitFor webDriver.deleteSession()

```
