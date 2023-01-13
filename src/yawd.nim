import json
import httpclient
import strutils
import strformat
import asyncdispatch
import base64
import uri
import times
import os
import asyncfile
import streams
import std/sha1

export json
export strutils
export strformat
export asyncdispatch

type
  WebDriver* = ref object
    host*: string
    port*: int
    url: string
    secure*: bool
    sessionId*: string
    client*: AsyncHttpClient

  ContextIdentifierType* = enum
    WindowIdentifier = "window-fcc6-11e5-b4f8-330a88ab9d7f"
    FrameIdentifier = "frame-075b-4da1-b6ba-e579c2d3230a"
    ElementIdentifier = "element-6066-11e4-a52e-4f735466cecf"
    ShadowRootIdentifier = "shadow-6066-11e4-a52e-4f735466cecf"

  PageLoadStrategyType* = enum
    None = "none"
    Eager = "eager"
    Normal = "normal"

  LocationElementStrategyType* = enum
    CssSelector = "css selector"
    LinkTextSelector = "link text"
    PartialLinkTextSelector = "partial link text"
    TagNameSelector = "tag name"
    XPathSelector = "xpath"

  HandleType* = enum
    Window = "window"
    Tab = "tab"

  PointerSubType* = enum
    Mouse = "mouse"
    Pen = "pen"
    Touch = "touch"

  ActionType* = enum
    Key = "key"
    Pointer = "pointer"
    Wheel = "wheel"
    Null = "none"

  ActionSubType* = enum
    Pause = "pause"
    KeyDown = "keyDown"
    KeyUp = "keyUP"
    PointerDown = "pointerDown"
    PointerUp = "pointerUp"
    PointerMove = "pointerMove"
    PointerCancel = "pointerCancel"
    Scroll = "scroll"

  ActionOriginType* = enum
    ViewportOrigin = "viewport"
    PointerOrigin = "pointer"

  NUllAction* = ref object of RootObj

  Action*[T] = ref object of NullAction
    id*: string
    `type`*: ActionType
    actions*: seq[T]

  ScrollAction* = ref object of NullAction
    `type`*: ActionSubType
    duration*: int
    origin*: ActionOriginType
    x*: int
    y*: int
    deltaX*: int
    deltaY*: int

  PauseAction* = ref object of NullAction
    `type`*: ActionSubType
    duration*: int

  KeyAction* = ref object of NullAction
    `type`*: ActionSubType
    value*: string

  PointerActionBase* = ref object of NullAction
    `type`*: ActionSubType
    width*: int
    height*: int
    pressure*: float
    tangentialPressure*: float
    tiltX*: int
    tiltY*: int
    twist*: int
    altitudeAngle*: int
    azimuthAngle*: int

  PointerPressAction* = ref object of PointerActionBase
    button*: int

  PointerMoveAction* = ref object of PointerActionBase
    duration*: int
    origin*: ActionOriginType
    x*: int
    y*: int
  
  PointerCancelAction* = ref object of NullAction
    `type`*: ActionSubType

  PointerActionParameter* = ref object
    pointerType*: PointerSubType

proc newAction*[T: PointerPressAction or PointerMoveAction or ScrollAction or KeyAction or NullAction](id: string): Action[T] =
  ##
  ##  create new action
  ##
  var `type`: ActionType
  
  if T is PointerPressAction or T is PointerMoveAction: `type` = ActionType.Pointer
  elif T is ScrollAction: `type` = ActionType.Wheel
  elif T is KeyAction: `type` = ActionType.Key
  elif T is NUllAction: `type` = ActionType.Null

  result = Action[T](id: id, `type`: `type`)

proc newScrollAction*(deltaX, deltaY: int, duration: int = 1, x, y: int = 0, origin: ActionOriginType = ActionOriginType.ViewportOrigin): ScrollAction =
  ##
  ##  create new wheel action
  ##
  result = ScrollAction(`type`: ActionSubType.Scroll, duration: duration, x: x, y: y, deltaX: deltaX, deltaY: deltaY, origin: origin)

proc newPauseAction*(duration: int): PauseAction =
  ##
  ##  create new pause action
  ##
  result = PauseAction(`type`: ActionSubType.Pause, duration: duration)

proc newKeyUpAction*(value: string): KeyAction =
  ##
  ##  create new key up action
  ##
  result = KeyAction(`type`: ActionSubType.KeyUp, value: value)

proc newKeyDownAction*(value: string): KeyAction =
  ##
  ##  create new key down action
  ##
  result = KeyAction(`type`: ActionSubType.KeyDown, value: value)

proc newPointerUpAction*(width, height, button: int, pressure, tangentialPressure: float = 0, tiltX, tiltY, twist, altitudeAngle, azimuthAngle: int = 0): PointerPressAction =
  ##
  ##  create pointer up action
  ##
  result = PointerPressAction(`type`: ActionSubType.PointerUp, width: width, height: height, button: button, pressure: pressure, tangentialPressure: tangentialPressure, tiltX: tiltX, tiltY: tiltY, twist: twist, altitudeAngle: altitudeAngle, azimuthAngle: azimuthAngle)

proc newPointerDownAction*(width, height, button: int, pressure, tangentialPressure: float = 0, tiltX, tiltY, twist, altitudeAngle, azimuthAngle: int = 0): PointerPressAction =
  ##
  ##  create pointer down action
  ##
  result = PointerPressAction(`type`: ActionSubType.PointerDown, width: width, height: height, button: button, pressure: pressure, tangentialPressure: tangentialPressure, tiltX: tiltX, tiltY: tiltY, twist: twist, altitudeAngle: altitudeAngle, azimuthAngle: azimuthAngle)

proc newPointerMoveAction*(x, y, width, height: int, pressure, tangentialPressure: float = 0, duration, tiltX, tiltY, twist, altitudeAngle, azimuthAngle: int = 0, origin: ActionOriginType = ActionOriginType.ViewportOrigin): PointerMoveAction =
  ##
  ##  create pointer move action
  ##
  result = PointerMoveAction(`type`: ActionSubType.PointerMove, x: x, y: y, width: width, height: height, pressure: pressure, tangentialPressure: tangentialPressure, duration: duration, tiltX: tiltX, tiltY: tiltY, twist: twist, altitudeAngle: altitudeAngle, azimuthAngle: azimuthAngle, origin: origin)

proc newPointerCancelAction*(): PointerCancelAction =
  ##
  ##  create pointer cancel action
  ##
  result = PointerCancelAction(`type`: ActionSubType.PointerCancel)

proc newWebDriver*(host: string, port: int, secure: bool = false): WebDriver =
  ##
  ##  create new webdriver object with host, port, secure (default false)
  ##
  var h = host.toLower.replace("http://", "").replace("https://", "")
  if secure: h = &"https://{h}:{port}" else: h = &"http://{h}:{port}"
  result = WebDriver(host: host, port: port, url: h, secure: secure, client: newAsyncHttpClient())

proc newHttpRequest*(): AsyncHttpClient =
  ##
  ##  create httpclient object
  ##
  result = newAsyncHttpClient()

proc newResponseMsg*(): JsonNode =
  ##
  ##  create new response msg for each request
  ##  make it standard output
  ##
  result = %*{
    "status": $Http405,
    "success": false,
    "error": {},
    "data": {}
  }

proc prepareRequestPostJsonHeaders(self: WebDriver) =
  ##
  ##  prepare request post json header
  ##  this will call prepareRequestHeaders
  ##
  self.client.headers.clear()
  self.client.headers["Content-Type"] = "application/json"

proc prepareRequestHeaders(self: WebDriver) =
  ##
  ##  prepare request post json header
  ##  this will call prepareRequestHeaders
  ##
  self.client.headers.clear()

proc toResponseMsg(response: AsyncResponse): Future[JsonNode] {.async.} =
  ##
  ## Response format, will return JsonNode
  ## {
  ##    status: "200 OK",
  ##    success: true,
  ##    error: {},
  ##    data: {}
  ## }
  ##
  let responseMsg = newResponseMsg()
  responseMsg{"status"} = %response.status
  let body = await response.body
  if (cast[HttpCode](response.status.split(" ")[0].parseInt)).is2xx:
    responseMsg{"success"} = %true
    try:
      responseMsg{"data"} = % body.parseJson
    except:
      responseMsg{"data"}{"msg"} = %body

  else:
    try:
      responseMsg{"error"} = % body.parseJson
    except:
      responseMsg{"error"}{"msg"} = %body

  result = responseMsg

proc newSession*(self: WebDriver, jsonData: JsonNode): Future[JsonNode] {.async.} =
  ##
  ##  create new webdriver session
  ##  https://www.w3.org/TR/webdriver/#dfn-new-sessions
  ##
  self.prepareRequestPostJsonHeaders

  let res = await self.client.post(&"{self.url}/session", $jsonData)

  result = await res.toResponseMsg

  if result{"success"}.getBool:
    self.sessionId = result{"data"}{"value"}{"sessionId"}.getStr

proc deleteSession*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  delete session webdriver session
  ##  https://www.w3.org/TR/webdriver/#dfn-delete-session
  ##
  self.prepareRequestHeaders

  let res = await self.client.delete(&"{self.url}/session/{self.sessionId}")

  result = await res.toResponseMsg

proc getStatus*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  Status returns information about whether a remote end is in a state in which it can create new sessions, but may additionally include arbitrary meta information that is specific to the implementation.
  ##  The remote end’s readiness state is represented by the ready property of the body, which is false if an attempt to create a session at the current time would fail. However, the value true does not guarantee that a New Session command will succeed.
  ##  https://www.w3.org/TR/webdriver/#dfn-status
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/status")

  result = await res.toResponseMsg

proc getTimeouts*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  Let timeouts be the result of trying to JSON deserialize as a timeouts configuration the request’s parameters.
  ##  https://www.w3.org/TR/webdriver/#dfn-get-timeouts
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/timeouts")

  result = await res.toResponseMsg

proc setTimeouts*(self: WebDriver, implicit: int64 = -1, pageLoad: int64 = -1, script: int64 = -1): Future[JsonNode] {.async.} =
  ##
  ##  Let timeouts be the result of trying to JSON deserialize as a timeouts configuration the request’s parameters.
  ##  https://www.w3.org/TR/webdriver/#dfn-set-timeouts
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{}
  if implicit > -1: jsonData["implicit"] = %implicit
  if pageLoad > -1: jsonData["pageLoad"] = %pageLoad
  if script > -1: jsonData["script"] = %script

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/timeouts", $jsonData)

  result = await res.toResponseMsg

proc navigateTo*(self: WebDriver, url: string, pageLoadStrategy: PageLoadStrategyType = PageLoadStrategyType.Normal): Future[JsonNode] {.async.} =
  ##
  ##  The command causes the user agent to navigate the current top-level browsing context to a new location.
  ##  If the session is not in a secure TLS state, no certificate errors that would normally cause the user agent to abort and show a security warning are to hinder navigation to the requested address.
  ##  https://www.w3.org/TR/webdriver/#dfn-navigate-to
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{"url": url, "pageLoadStrategy": PageLoadStrategyType.Normal}

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/url", $jsonData)

  result = await res.toResponseMsg

proc getCurrentUrl*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  get current top level browsing url
  ##  https://www.w3.org/TR/webdriver/#dfn-get-current-url
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/url")

  result = await res.toResponseMsg

proc back*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  This command causes the browser to traverse one step backward in the joint session history of the current top-level browsing context. This is equivalent to pressing the back button in the browser chrome or invoking window.history.back.
  ##  https://www.w3.org/TR/webdriver/#dfn-back
  ##
  self.prepareRequestPostJsonHeaders

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/back", $ %*{})

  result = await res.toResponseMsg

proc forward*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  This command causes the browser to traverse one step forwards in the joint session history of the current top-level browsing context. This is equivalent to pressing the forward button in the browser chrome or invoking window.history.forward.
  ##  https://www.w3.org/TR/webdriver/#dfn-forward
  ##
  self.prepareRequestPostJsonHeaders

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/forward", $ %*{})

  result = await res.toResponseMsg

proc refresh*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  This command causes the browser to reload the page in the current top-level browsing context.
  ##  https://www.w3.org/TR/webdriver/#dfn-refresh
  ##
  self.prepareRequestPostJsonHeaders

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/refresh", $ %*{})

  result = await res.toResponseMsg

proc getTitle*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  This command returns the document title of the current top-level browsing context, equivalent to calling document.title.
  ##  https://www.w3.org/TR/webdriver/#dfn-get-title
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/title")

  result = await res.toResponseMsg

proc getWindowHandle*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  get current windows (top level) browsing context
  ##  https://www.w3.org/TR/webdriver/#dfn-get-window-handle
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/window")

  result = await res.toResponseMsg

proc getWindowHandles*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  The order in which the window handles are returned is arbitrary.
  ##  https://www.w3.org/TR/webdriver/#dfn-get-window-handles
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/window/handles")

  result = await res.toResponseMsg

proc closeWindow*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  close current window (top level) browsing context
  ##  https://www.w3.org/TR/webdriver/#dfn-close-window
  ##
  self.prepareRequestHeaders

  let res = await self.client.delete(&"{self.url}/session/{self.sessionId}/window")

  result = await res.toResponseMsg

proc switchToWindow*(self: WebDriver, handle: string): Future[JsonNode] {.async.} =
  ##
  ##  Switching window will select the current top-level browsing context used as the target for all subsequent commands. In a tabbed browser, this will typically make the tab containing the browsing context the selected tab.
  ##  https://www.w3.org/TR/webdriver/#dfn-switch-to-window
  ##
  self.prepareRequestPostJsonHeaders

  let jsonParam = %*{"handle": handle}

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/window", $jsonParam)

  result = await res.toResponseMsg

proc newWindow*(self: WebDriver, handle: string = "", handleType: HandleType = HandleType.Tab): Future[JsonNode] {.async.} =
  ##
  ##  Create a new top-level browsing context.
  ##  https://www.w3.org/TR/webdriver/#dfn-new-window
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{}
  if handle != "": jsonData["handle"] = %handle
  jsonData["type"] = %handleType

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/window/new", $jsonData)

  result = await res.toResponseMsg

proc switchToFrame*(self: WebDriver, id: int): Future[JsonNode] {.async.} =
  ##
  ##  The Switch To Frame command is used to select the current top-level browsing context or a child browsing context of the current browsing context to use as the current browsing context for subsequent commands.
  ##  https://www.w3.org/TR/webdriver/#dfn-switch-to-frame
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{"id": id}

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/frame", $jsonData)

  result = await res.toResponseMsg

proc switchToParentFrame*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  The Switch to Parent Frame command sets the current browsing context for future commands to the parent of the current browsing context.
  ##  https://www.w3.org/TR/webdriver/#dfn-switch-to-parent-frame
  ##
  self.prepareRequestPostJsonHeaders

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/frame/parent", $ %*{})

  result = await res.toResponseMsg

proc getWindowRect*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  The Get Window Rect command returns the size and position on the screen of the operating system window corresponding to the current top-level browsing context.
  ##  https://www.w3.org/TR/webdriver/#dfn-get-window-rect
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/window/rect")

  result = await res.toResponseMsg

proc fullscreenWindow*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-fullscreen-window
  ##
  self.prepareRequestPostJsonHeaders

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/window/fullscreen", $ %*{})

  result = await res.toResponseMsg

proc minimizeWindow*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  The Minimize Window command invokes the window manager-specific “minimize” operation, if any, on the window containing the current top-level browsing context. This typically hides the window in the system tray.
  ##  https://www.w3.org/TR/webdriver/#dfn-minimize-window
  ##
  self.prepareRequestPostJsonHeaders

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/window/minimize", $ %*{})

  result = await res.toResponseMsg

proc maximizeWindow*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  The Maximize Window command invokes the window manager-specific “maximize” operation, if any, on the window containing the current top-level browsing context. This typically increases the window to the maximum available size without going full-screen.
  ##  https://www.w3.org/TR/webdriver/#dfn-maximize-window
  ##
  self.prepareRequestPostJsonHeaders

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/window/maximize", $ %*{})

  result = await res.toResponseMsg

proc setWindowRect*(self: WebDriver, width, height, x, y: int = -1): Future[JsonNode] {.async.} =
  ##
  ##  The Set Window Rect command alters the size and the position of the operating system window corresponding to the current top-level browsing context.
  ##  https://www.w3.org/TR/webdriver/#dfn-set-window-rect
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{}
  if width > -1: jsonData["width"] = %width
  if height > -1: jsonData["height"] = %height
  if x > -1: jsonData["x"] = %x
  if y > -1: jsonData["y"] = %y

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/window/rect", $jsonData)

  result = await res.toResponseMsg

proc getActiveElement*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-active-element
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/active")

  result = await res.toResponseMsg

proc getElementShadowRoot*(self: WebDriver, elementId: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-active-element
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{elementId}/shadow")

  result = await res.toResponseMsg

proc findElement*(self: WebDriver, query: string, locationElementStrategy: LocationElementStrategyType = LocationElementStrategyType.CssSelector): Future[JsonNode] {.async.} =
  ##
  ##  The Find Element command is used to find an element in the current browsing context that can be used as the web element context for future element-centric commands.
  ##  ##For example, consider this pseudo code which retrieves an element with the #toremove ID and uses this as the argument for a script it injects to remove it from the HTML document:
  ##
  ##  let body = session.find.css("#toremove");
  ##  session.execute("arguments[0].remove()", [body]);
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-active-element
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{
    "using": locationElementStrategy,
    "value": query
  }

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/element", $jsonData)

  result = await res.toResponseMsg

proc findElements*(self: WebDriver, query: string, locationElementStrategy: LocationElementStrategyType = LocationElementStrategyType.CssSelector): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-find-elements
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{
    "using": locationElementStrategy,
    "value": query
  }

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/elements", $jsonData)

  result = await res.toResponseMsg

proc findElement*(self: WebDriver, fromElement: string, query: string, locationElementStrategy: LocationElementStrategyType = LocationElementStrategyType.CssSelector): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-find-element-from-element
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{
    "using": locationElementStrategy,
    "value": query
  }

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/element/{fromElement}/element", $jsonData)

  result = await res.toResponseMsg

proc findElements*(self: WebDriver, fromElement: string, query: string, locationElementStrategy: LocationElementStrategyType = LocationElementStrategyType.CssSelector): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-find-elements-from-element
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{
    "using": locationElementStrategy,
    "value": query
  }

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/element/{fromElement}/elements", $jsonData)

  result = await res.toResponseMsg

proc findElementFromShadowRoot*(self: WebDriver, fromShadowRoot: string, query: string, locationElementStrategy: LocationElementStrategyType = LocationElementStrategyType.CssSelector): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-find-element-from-shadow-root
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{
    "using": locationElementStrategy,
    "value": query
  }

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/shadow/{fromShadowRoot}/element", $jsonData)

  result = await res.toResponseMsg

proc findElementsFromShadowRoot*(self: WebDriver, fromShadowRoot: string, query: string, locationElementStrategy: LocationElementStrategyType = LocationElementStrategyType.CssSelector): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-find-elements-from-shadow-root
  ##
  self.prepareRequestPostJsonHeaders

  let jsonData = %*{
    "using": locationElementStrategy,
    "value": query
  }

  let res = await self.client.post(&"{self.url}/session/{self.sessionId}/shadow/{fromShadowRoot}/elements", $jsonData)

  result = await res.toResponseMsg

proc isElementSelected*(self: WebDriver, element: string): Future[JsonNode] {.async.} =
  ##
  ##  The Is Element Selected command determines if the referenced element is selected or not. This operation only makes sense on input elements of the Checkbox- and Radio Button states, or on option elements.
  ##  https://www.w3.org/TR/webdriver/#dfn-is-element-selected
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{element}/selected")

  result = await res.toResponseMsg

proc getElementAttribute*(self: WebDriver, element: string, attribute: string): Future[JsonNode] {.async.} =
  ##
  ##  Please note that the behavior of this command deviates from the behavior of getAttribute() in [DOM], which in the case of a set boolean attribute would return an empty string. The reason this command returns true as a string is because this evaluates to true in most dynamically typed programming languages, but still preserves the expected type information.
  ##  https://www.w3.org/TR/webdriver/#dfn-get-element-attribute
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{element}/attribute/{attribute}")

  result = await res.toResponseMsg

proc getElementProperty*(self: WebDriver, element: string, property: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-element-property
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{element}/property/{property}")

  result = await res.toResponseMsg

proc getElementCssValue*(self: WebDriver, element: string, property: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-element-css-value
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{element}/css/{property}")

  result = await res.toResponseMsg

proc getElementText*(self: WebDriver, element: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-element-text
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{element}/text")

  result = await res.toResponseMsg

proc getElementTagName*(self: WebDriver, element: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-element-tag-name
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{element}/name")

  result = await res.toResponseMsg

proc getElementRect*(self: WebDriver, element: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-element-rect
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{element}/rect")

  result = await res.toResponseMsg

proc isElementEnabled*(self: WebDriver, element: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-is-element-enabled
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{element}/enabled")

  result = await res.toResponseMsg

proc getComputedRole*(self: WebDriver, element: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-computed-role
  ##
  self.prepareRequestHeaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionId}/element/{element}/computedrole")

  result = await res.toResponseMsg

proc getcomputedlabel*(self: WebDriver, element: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/tr/webdriver/#dfn-get-computed-label
  ##
  self.prepareRequestheaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionid}/element/{element}/computedlabel")

  result = await res.toresponsemsg

proc elementClick*(self: WebDriver, element: string): Future[JsonNode] {.async.} =
  ##
  ##  The Element Click command scrolls into view the element if it is not already pointer-interactable, and clicks its in-view center point.
  ##  If the element’s center point is obscured by another element, an element click intercepted error is returned. If the element is outside the viewport, an element not interactable error is returned.
  ##  https://www.w3.org/TR/webdriver/#dfn-element-click
  ##
  self.prepareRequestPostJsonheaders

  let res = await self.client.post(&"{self.url}/session/{self.sessionid}/element/{element}/click", $ %*{})

  result = await res.toresponsemsg

proc elementClear*(self: WebDriver, element: string): Future[JsonNode] {.async.} =
  ##https://www.w3.org/TR/webdriver/#dfn-element-clear
  ##  https://www.w3.org/TR/webdriver/#dfn-element-clear
  ##
  self.prepareRequestPostJsonheaders

  let res = await self.client.post(&"{self.url}/session/{self.sessionid}/element/{element}/clear", $ %*{})

  result = await res.toresponsemsg

proc elementSendKeys*(self: WebDriver, element: string, text: string): Future[JsonNode] {.async.} =
  ##
  ##  The Element Send Keys command scrolls into view the form control element and then sends the provided keys to the element. In case the element is not keyboard-interactable, an element not interactable error is returned.
  ##  https://www.w3.org/TR/webdriver/#dfn-element-send-keys
  ##
  self.prepareRequestPostJsonheaders

  let jsonData = %*{"text": text}

  let res = await self.client.post(&"{self.url}/session/{self.sessionid}/element/{element}/value", $jsonData)

  result = await res.toresponsemsg

proc getPageSource*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  The Get Page Source command returns a string serialization of the DOM of the current browsing context active document.
  ##  https://www.w3.org/TR/webdriver/#dfn-get-page-source
  ##
  self.prepareRequestheaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionid}/source")

  result = await res.toresponsemsg

proc executeScript*(self: WebDriver, script: string, args: seq[JsonNode] = @[]): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-execute-script
  ##
  self.prepareRequestPostJsonheaders

  let jsonData = %*{
    "script": script,
    "args": %args
  }

  let res = await self.client.post(&"{self.url}/session/{self.sessionid}/execute/sync", $jsonData)

  result = await res.toresponsemsg

proc executeScriptAsync*(self: WebDriver, script: string, args: seq[JsonNode] = @[]): Future[JsonNode] {.async.} =
  ##
  ##  The Execute Async Script command causes JavaScript to execute as an anonymous function. An additional value is provided as the final argument to the function. This is a function that may be invoked to signal the completion of the asynchronous operation. The first argument provided to the function will be serialized to JSON and returned by Execute Async Script.
  ##  https://www.w3.org/TR/webdriver/#dfn-execute-async-script
  ##
  self.prepareRequestPostJsonheaders

  let jsonData = %*{
    "script": script,
    "args": %args
  }

  let res = await self.client.post(&"{self.url}/session/{self.sessionid}/execute/async", $jsonData)

  result = await res.toresponsemsg

proc getAllCookies*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-all-cookies
  ##
  self.prepareRequestheaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionid}/cookie")

  result = await res.toresponsemsg

proc getNamedCookie*(self: WebDriver, name: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-get-named-cookie
  ##
  self.prepareRequestheaders

  let res = await self.client.get(&"{self.url}/session/{self.sessionid}/cookie/{name}")

  result = await res.toresponsemsg

proc addCookie*(self: WebDriver, name: string, value: string, domain: string = "", expiry: int64 = -999999, httpOnly: bool = false, path: string = "/", sameSite: string = "None", secure: bool = false): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-adding-a-cookie
  ##
  self.prepareRequestheaders

  let jsonData = %*{
    "cookie": {
      "name": name,
      "value": value,
      "httpOnly": httpOnly,
      "path": path,
      "sameSite": sameSite
    }
  }

  if domain != "": jsonData["cookie"]["domain"] = %domain
  if expiry > -999999: jsonData["cookie"]["expiry"] = %expiry

  let res = await self.client.post(&"{self.url}/session/{self.sessionid}/cookie", $jsonData)

  result = await res.toresponsemsg

proc deleteCookie*(self: WebDriver, name: string): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-delete-cookie
  ##
  self.prepareRequestheaders

  let res = await self.client.delete(&"{self.url}/session/{self.sessionid}/cookie/{name}")

  result = await res.toresponsemsg

proc deleteAllCookies*(self: WebDriver): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-delete-all-cookies
  ##
  self.prepareRequestheaders

  let res = await self.client.delete(&"{self.url}/session/{self.sessionid}/cookie")

  result = await res.toresponsemsg

proc performActions*(self: WebDriver, actions: seq[JsonNode]): Future[JsonNode] {.async.} =
  ##
  ##  https://www.w3.org/TR/webdriver/#dfn-perform-actions
  ##
  self.prepareRequestPostJsonheaders

  let jsonData = %*{"actions": actions}

  let res = await self.client.post(&"{self.url}/session/{self.sessionid}/actions", $jsonData)

  result = await res.toresponsemsg

if isMainModule:
  let webDriver = newWebDriver(host = "127.0.0.1", port = 9515)
  
  ##  create new session
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

  ##  Test action
  var actions: seq[JsonNode]

  var scrollAction = newAction[ScrollAction]("wheel")
  scrollAction.actions.add(newScrollAction(deltaX = 500, deltaY = 500))
  actions.add(%scrollAction)

  echo actions
  echo waitFor webDriver.performActions(actions)

  echo waitFor webDriver.closeWindow()
  echo waitFor webDriver.deleteSession()
