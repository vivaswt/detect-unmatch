{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Main (main) where

import Data.List (find, sort)
import Data.Maybe (fromMaybe)
import Data.Text (takeEnd)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.Text.Read as TR
import Flow
import Monatone.Common (parseMetadata)
import Monatone.Metadata (Metadata (album, artist, title, trackNumber))
import System.Directory.OsPath (listDirectory)
import System.OsPath (OsPath, decodeFS, osp, takeExtension, takeFileName, unsafeEncodeUtf, (</>))
import Text.RawString.QQ (r)
import Text.Regex.TDFA ((=~))

main :: IO ()
main = do
  files <- findMp3Files musicDir
  infoResult <- extractMp3Info files
  case infoResult of
    Left errMsg -> TIO.putStrLn errMsg
    Right mp3Infos -> do
      unmatchedResult <- findUnmatchedPosition mp3Infos
      showResult unmatchedResult

findMp3Files :: OsPath -> IO [OsPath]
findMp3Files = medleyDirectories .> mapM mp3FilesInDirectory .> fmap concat

extractMp3Info :: [OsPath] -> IO (Either T.Text [Mp3Info])
extractMp3Info paths = do
  parseResults <- mapM parseMp3Info paths
  parseResults |> sequence |> return

showResult :: Maybe (SongPosition, SongPosition) -> IO ()
showResult Nothing =
  TIO.putStrLn "No unmatched found."
showResult (Just unmatched) =
  unmatched |> formatUnmatchedPosition |> TIO.putStrLn

osPathToTextFS :: OsPath -> IO T.Text
osPathToTextFS = decodeFS .> fmap T.pack

musicDir :: OsPath
musicDir = [osp|/mnt/c/Users/vivas/Music|]

medleyDirectories :: OsPath -> [OsPath]
medleyDirectories parentPath =
  [parentPath </> dirName n | n <- [1 .. 14 :: Int]]
  where
    dirName n = unsafeEncodeUtf "メドレー" <> intToOsPath n
    intToOsPath = unsafeEncodeUtf . zeroPad 2 . show
    zeroPad width str = replicate (width - length str) '0' ++ str

mp3FilesInDirectory :: OsPath -> IO [OsPath]
mp3FilesInDirectory path = do
  files <- listDirectory path
  files
    |> filterMp3
    |> sort
    |> map editAbsPath
    |> return
  where
    hasMp3Ext = takeExtension .> (==) [osp|.mp3|]
    filterMp3 = filter hasMp3Ext
    editAbsPath = (</>) path

parseMp3Info :: OsPath -> IO (Either T.Text Mp3Info)
parseMp3Info path = do
  result <- parseMetadata path
  case result of
    Left _ -> return $ Left "failed to parse mp3"
    Right metadata ->
      Mp3Info
        { mp3InfoFileName = takeFileName path,
          mp3InfoPath = path,
          mp3InfoTitle = fromMaybe "" . title $ metadata,
          mp3InfoArtist = fromMaybe "" . artist $ metadata,
          mp3InfoAlbum = fromMaybe "" . album $ metadata,
          mp3InfoTrackNumber = fromMaybe 0 . trackNumber $ metadata
        }
        |> Right
        |> return

extractSongPositionFromFileName :: Mp3Info -> IO SongPosition
extractSongPositionFromFileName mp3Info = do
  fileNameText <- mp3Info |> mp3InfoFileName |> osPathToTextFS
  let numbers = extractNumbers fileNameText

  case numbers of
    [n1, n2] ->
      SongPosition
        { songPositionAlbumNumber = textToInt n1,
          songPositionTrackNumber = textToInt n2
        }
        |> return
    _ ->
      SongPosition
        { songPositionAlbumNumber = 0,
          songPositionTrackNumber = 0
        }
        |> return
  where
    extractNumbers :: T.Text -> [T.Text]
    extractNumbers fname =
      ((fname =~ regExp) :: (T.Text, T.Text, T.Text, [T.Text]))
        |> \(_, _, _, subs) -> subs

    regExp :: T.Text
    regExp = [r|\`([0-9]{2})-([0-9]{2})\.mp3\'|]

extractSongPositionFromMp3Tag :: Mp3Info -> SongPosition
extractSongPositionFromMp3Tag mp3Info =
  SongPosition
    { songPositionAlbumNumber = alNumber,
      songPositionTrackNumber = trNumber
    }
  where
    alNumber = mp3Info |> mp3InfoAlbum |> takeEnd 2 |> textToInt
    trNumber = mp3InfoTrackNumber mp3Info

textToInt :: T.Text -> Int
textToInt t = case TR.decimal t of
  Right (n, _) -> n
  _ -> 0

findUnmatchedPosition :: [Mp3Info] -> IO (Maybe (SongPosition, SongPosition))
findUnmatchedPosition mp3Infos = do
  spsFromFileName <- mapM extractSongPositionFromFileName mp3Infos
  let spsFromTag =
        map extractSongPositionFromMp3Tag mp3Infos
  zip spsFromFileName spsFromTag
    |> find positionsAreUnmatched
    |> return
  where
    positionsAreUnmatched (p1, p2) = p1 /= p2

formatUnmatchedPosition :: (SongPosition, SongPosition) -> T.Text
formatUnmatchedPosition (psFromFileName, psFromMp3Tag) =
  "fileName"
    <> formatSongPosition psFromFileName
    <> "-"
    <> "tag"
    <> formatSongPosition psFromMp3Tag

formatSongPosition :: SongPosition -> T.Text
formatSongPosition
  SongPosition {songPositionAlbumNumber = alNumber, songPositionTrackNumber = trNumber} =
    "(Album:" <> intToText alNumber <> ", Track:" <> intToText trNumber <> ")"

intToText :: Int -> T.Text
intToText = show .> T.pack

data Mp3Info = Mp3Info
  { mp3InfoFileName :: OsPath,
    mp3InfoPath :: OsPath,
    mp3InfoTitle :: T.Text,
    mp3InfoArtist :: T.Text,
    mp3InfoAlbum :: T.Text,
    mp3InfoTrackNumber :: Int
  }

data SongPosition = SongPosition
  { songPositionAlbumNumber :: Int,
    songPositionTrackNumber :: Int
  }
  deriving (Eq)